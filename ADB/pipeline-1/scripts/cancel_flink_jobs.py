import sys
from typing import Any

import requests


def cancel_all_jobs(flink_base_url: str) -> int:
    normalized_base_url = flink_base_url.rstrip("/")
    overview_response = requests.get(
        f"{normalized_base_url}/jobs/overview",
        timeout=30,
    )
    overview_response.raise_for_status()

    jobs_payload: dict[str, Any] = overview_response.json()
    jobs = jobs_payload.get("jobs", [])

    cancellable_statuses = {
        "RUNNING",
        "RESTARTING",
        "CREATED",
        "DEPLOYING",
        "INITIALIZING",
    }
    job_identifier_list = [
        job["jid"] for job in jobs if job.get("state") in cancellable_statuses
    ]

    if not job_identifier_list:
        print("No cancellable jobs found.")
        return 0

    for job_identifier in job_identifier_list:
        cancel_response = requests.patch(
            f"{normalized_base_url}/jobs/{job_identifier}",
            params={"mode": "cancel"},
            timeout=30,
        )
        cancel_response.raise_for_status()
        print(f"Cancelled {job_identifier}")

    return 0


if __name__ == "__main__":
    flink_base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8081"
    raise SystemExit(cancel_all_jobs(flink_base_url))
