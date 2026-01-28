import asyncio
import os
from db.progress_tracker_summary import ProgressTrackerSummary
from ms_agent.config import Config
from main import run_main

async def main():
    """Main function for non-patch mode."""
    path = os.path.dirname(os.path.abspath(__file__))
    code_agent_config = os.path.join(path, "coding.yaml")
    code_config = Config.from_task(code_agent_config)
    output_dir = getattr(code_config, "output_dir", "output")

    tracker = ProgressTrackerSummary(db_path=os.path.join(path, output_dir, "progress.db"))
    return await run_main(refine_config_path="refine_summary.yaml", tracker=tracker)


if __name__ == '__main__':
    # Launch the async main function
    asyncio.run(main())
