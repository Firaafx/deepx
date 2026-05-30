from __future__ import annotations

import asyncio
import mimetypes
import os
import shlex
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx
from fastapi import BackgroundTasks, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field


SOURCE_BUCKET_FALLBACK = "deepx-3d-sources"
ASSET_BUCKET = os.getenv("THREE_D_ASSETS_BUCKET", "deepx-3d-assets")
PREFERRED_FORMAT = os.getenv("PREFERRED_SPLAT_FORMAT", "ksplat").lstrip(".")

app = FastAPI(title="DeepX InstantSplat Worker")


class StartJobRequest(BaseModel):
    job_id: str = Field(min_length=1)
    supabase_url: str | None = None


def _service_key() -> str:
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not key:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY is not configured.")
    return key


def _supabase_url(request_url: str | None) -> str:
    value = (request_url or os.getenv("SUPABASE_URL") or "").strip().rstrip("/")
    if not value:
        raise RuntimeError("Supabase URL is not configured.")
    return value


def _rest_headers() -> dict[str, str]:
    key = _service_key()
    return {
        "apikey": key,
        "authorization": f"Bearer {key}",
        "content-type": "application/json",
    }


async def _patch_job(
    client: httpx.AsyncClient,
    supabase_url: str,
    job_id: str,
    values: dict[str, Any],
) -> None:
    response = await client.patch(
        f"{supabase_url}/rest/v1/splat_generation_jobs",
        params={"id": f"eq.{job_id}"},
        headers={**_rest_headers(), "prefer": "return=minimal"},
        json=values,
    )
    response.raise_for_status()


async def _validate_user(
    client: httpx.AsyncClient,
    supabase_url: str,
    authorization: str,
) -> dict[str, Any]:
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    response = await client.get(
        f"{supabase_url}/auth/v1/user",
        headers={
            "apikey": _service_key(),
            "authorization": authorization,
        },
    )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid Supabase token.")
    return response.json()


async def _fetch_job(
    client: httpx.AsyncClient,
    supabase_url: str,
    job_id: str,
) -> dict[str, Any]:
    response = await client.get(
        f"{supabase_url}/rest/v1/splat_generation_jobs",
        params={"id": f"eq.{job_id}", "select": "*"},
        headers=_rest_headers(),
    )
    response.raise_for_status()
    rows = response.json()
    if not rows:
        raise HTTPException(status_code=404, detail="Job not found.")
    return rows[0]


async def _download_sources(
    client: httpx.AsyncClient,
    supabase_url: str,
    job: dict[str, Any],
    input_dir: Path,
) -> list[Path]:
    bucket = job.get("source_bucket") or SOURCE_BUCKET_FALLBACK
    source_paths = job.get("source_image_paths") or []
    if len(source_paths) < 3:
        raise RuntimeError("InstantSplat needs at least 3 source images.")

    downloaded: list[Path] = []
    for index, source_path in enumerate(source_paths):
        encoded_path = quote(str(source_path), safe="/")
        response = await client.get(
            f"{supabase_url}/storage/v1/object/{bucket}/{encoded_path}",
            headers={
                "apikey": _service_key(),
                "authorization": f"Bearer {_service_key()}",
            },
        )
        response.raise_for_status()
        suffix = Path(str(source_path)).suffix or ".jpg"
        target = input_dir / f"source_{index:03d}{suffix}"
        target.write_bytes(response.content)
        downloaded.append(target)
    return downloaded


async def _run_instantsplat(input_dir: Path, output_dir: Path, job_id: str) -> Path:
    command_template = os.getenv("INSTANTSPLAT_COMMAND", "").strip()
    if not command_template:
        raise RuntimeError("INSTANTSPLAT_COMMAND is not configured.")

    output_path = output_dir / f"scene.{PREFERRED_FORMAT}"
    command = command_template.format(
        input_dir=str(input_dir),
        output_dir=str(output_dir),
        output_path=str(output_path),
        job_id=job_id,
    )

    if os.getenv("INSTANTSPLAT_COMMAND_SHELL") == "1":
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    else:
        process = await asyncio.create_subprocess_exec(
            *shlex.split(command),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    stdout, stderr = await process.communicate()
    if process.returncode != 0:
        message = stderr.decode("utf-8", "ignore") or stdout.decode(
            "utf-8",
            "ignore",
        )
        raise RuntimeError(message.strip() or "InstantSplat failed.")

    if output_path.exists():
        return output_path

    candidates: list[Path] = []
    for pattern in ("*.ksplat", "*.splat", "*.ply"):
        candidates.extend(output_dir.rglob(pattern))
    if not candidates:
        raise RuntimeError("InstantSplat finished without a splat output.")
    return candidates[0]


async def _upload_asset(
    client: httpx.AsyncClient,
    supabase_url: str,
    user_id: str,
    job_id: str,
    asset_path: Path,
) -> tuple[str, str, str]:
    ext = asset_path.suffix.lstrip(".").lower() or PREFERRED_FORMAT
    storage_path = f"{user_id}/gaussian-splats/{job_id}/scene.{ext}"
    content_type = mimetypes.guess_type(asset_path.name)[0] or "application/octet-stream"
    response = await client.post(
        f"{supabase_url}/storage/v1/object/{ASSET_BUCKET}/{quote(storage_path, safe='/')}",
        headers={
            "apikey": _service_key(),
            "authorization": f"Bearer {_service_key()}",
            "content-type": content_type,
            "x-upsert": "true",
        },
        content=asset_path.read_bytes(),
    )
    response.raise_for_status()
    public_url = f"{supabase_url}/storage/v1/object/public/{ASSET_BUCKET}/{quote(storage_path, safe='/')}"
    return public_url, storage_path, ext


def _three_d_payload(
    *,
    asset_url: str,
    storage_path: str,
    fmt: str,
    byte_size: int,
    job: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "media": {
            "type": "gaussian_splat",
            "url": asset_url,
            "path": storage_path,
            "format": fmt,
            "contentType": "application/octet-stream",
            "bytes": byte_size,
        },
        "transform": {
            "scale": 1,
            "position": [0, 0, 0],
            "rotation": [0, 0, 0],
        },
        "source": {
            "kind": "instantsplat",
            "jobId": job["id"],
            "sourceImageCount": len(job.get("source_image_paths") or []),
        },
        "meta": {
            "editor": "instantsplat_worker",
        },
    }


async def _create_preset(
    client: httpx.AsyncClient,
    supabase_url: str,
    job: dict[str, Any],
    payload: dict[str, Any],
) -> str:
    response = await client.post(
        f"{supabase_url}/rest/v1/presets",
        headers={**_rest_headers(), "prefer": "return=representation"},
        json={
            "user_id": job["user_id"],
            "name": job.get("post_title") or "3D Scene",
            "title": job.get("post_title") or "3D Scene",
            "description": job.get("post_description") or "",
            "tags": job.get("post_tags") or [],
            "mention_user_ids": job.get("post_mention_user_ids") or [],
            "visibility": job.get("post_visibility") or "public",
            "media_type": "gaussian_splat",
            "payload": payload,
            "thumbnail_payload": job.get("thumbnail_payload") or {},
            "is_paid": job.get("is_paid") is True,
            "price_cents": job.get("price_cents"),
            "accent_color_hex": job.get("accent_color_hex"),
        },
    )
    response.raise_for_status()
    rows = response.json()
    return rows[0]["id"]


async def _run_job(job_id: str, supabase_url: str) -> None:
    async with httpx.AsyncClient(timeout=None) as client:
        try:
            await _patch_job(
                client,
                supabase_url,
                job_id,
                {"status": "running", "progress": 10, "stage": "Downloading sources"},
            )
            job = await _fetch_job(client, supabase_url, job_id)
            with tempfile.TemporaryDirectory(prefix=f"deepx-{job_id}-") as temp:
                root = Path(temp)
                input_dir = root / "input"
                output_dir = root / "output"
                input_dir.mkdir(parents=True, exist_ok=True)
                output_dir.mkdir(parents=True, exist_ok=True)

                await _download_sources(client, supabase_url, job, input_dir)
                await _patch_job(
                    client,
                    supabase_url,
                    job_id,
                    {"progress": 25, "stage": "Running InstantSplat"},
                )
                asset_file = await _run_instantsplat(input_dir, output_dir, job_id)
                await _patch_job(
                    client,
                    supabase_url,
                    job_id,
                    {"progress": 82, "stage": "Uploading 3D asset"},
                )
                public_url, storage_path, fmt = await _upload_asset(
                    client,
                    supabase_url,
                    str(job["user_id"]),
                    job_id,
                    asset_file,
                )
                payload = _three_d_payload(
                    asset_url=public_url,
                    storage_path=storage_path,
                    fmt=fmt,
                    byte_size=asset_file.stat().st_size,
                    job=job,
                )
                await _patch_job(
                    client,
                    supabase_url,
                    job_id,
                    {
                        "status": "finalizing",
                        "progress": 92,
                        "stage": "Publishing post",
                        "output_bucket": ASSET_BUCKET,
                        "output_asset_path": storage_path,
                        "output_payload": payload,
                    },
                )
                preset_id = await _create_preset(client, supabase_url, job, payload)
                await _patch_job(
                    client,
                    supabase_url,
                    job_id,
                    {
                        "status": "succeeded",
                        "progress": 100,
                        "stage": "Published",
                        "created_preset_id": preset_id,
                    },
                )
        except Exception as exc:
            await _patch_job(
                client,
                supabase_url,
                job_id,
                {
                    "status": "failed",
                    "stage": "Failed",
                    "error_message": str(exc)[:2000],
                },
            )


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok": True,
        "hasServiceKey": bool(os.getenv("SUPABASE_SERVICE_ROLE_KEY")),
        "hasInstantSplatCommand": bool(os.getenv("INSTANTSPLAT_COMMAND")),
    }


async def _start(
    request: StartJobRequest,
    background_tasks: BackgroundTasks,
    authorization: str | None,
) -> dict[str, str]:
    supabase_url = _supabase_url(request.supabase_url)
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization.")
    async with httpx.AsyncClient(timeout=30) as client:
        user = await _validate_user(client, supabase_url, authorization)
        job = await _fetch_job(client, supabase_url, request.job_id)
        if str(job.get("user_id")) != str(user.get("id")):
            raise HTTPException(status_code=403, detail="Job belongs to another user.")
        await _patch_job(
            client,
            supabase_url,
            request.job_id,
            {"status": "queued", "progress": 5, "stage": "Queued on worker"},
        )
    background_tasks.add_task(_run_job, request.job_id, supabase_url)
    return {"status": "accepted", "job_id": request.job_id}


@app.post("/")
async def start_root(
    request: StartJobRequest,
    background_tasks: BackgroundTasks,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    return await _start(request, background_tasks, authorization)


@app.post("/v1/jobs/start")
async def start_job(
    request: StartJobRequest,
    background_tasks: BackgroundTasks,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    return await _start(request, background_tasks, authorization)
