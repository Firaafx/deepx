# RayMax InstantSplat Worker

GPU worker contract for training Gaussian splats from uploaded source images.

## Endpoints

- `GET /health` returns worker status.
- `POST /` and `POST /v1/jobs/start` start a Supabase `splat_generation_jobs` row.

Flutter sends:

```json
{
  "job_id": "uuid",
  "supabase_url": "https://project.supabase.co"
}
```

The request must include the current Supabase user token:

```text
Authorization: Bearer <user access token>
```

## Required Environment

- `SUPABASE_SERVICE_ROLE_KEY`: service role key, kept only on this worker.
- `INSTANTSPLAT_COMMAND`: command template that writes a trained splat.

Template variables available to `INSTANTSPLAT_COMMAND`:

- `{input_dir}` source image directory
- `{output_dir}` output directory
- `{output_path}` preferred output file path, usually `scene.ksplat`
- `{job_id}` Supabase job id

Example:

```bash
INSTANTSPLAT_COMMAND="python /opt/InstantSplat/run.py --input {input_dir} --output {output_path}"
```

Optional:

- `SUPABASE_URL`: fallback Supabase URL when the request omits it.
- `THREE_D_ASSETS_BUCKET`: defaults to `raymax-3d-assets`.
- `PREFERRED_SPLAT_FORMAT`: defaults to `ksplat`.
- `INSTANTSPLAT_COMMAND_SHELL=1`: run the command through the shell.

The worker validates the user token, verifies the job belongs to that user,
downloads private source images with the service key, runs InstantSplat, uploads
the generated 3D asset, creates the final `presets` row, and marks the job as
`succeeded`. On failure it writes `status=failed` and `error_message`.
