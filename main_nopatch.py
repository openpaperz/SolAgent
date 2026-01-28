"""
Main entry point for non-patch mode (default mode).
Uses refine.yaml and ProgressTracker.
"""
import asyncio
import os
from main import run_main
from db.progress_tracker import ProgressTracker


async def main():
    """Main function for non-patch mode."""
    path = os.path.dirname(os.path.abspath(__file__))
    from ms_agent.config import Config
    code_agent_config = os.path.join(path, "coding.yaml")
    code_config = Config.from_task(code_agent_config)
    output_dir = getattr(code_config, "output_dir", "output")
    
    tracker = ProgressTracker(db_path=os.path.join(path, output_dir, "progress.db"))
    return await run_main(refine_config_path="refine.yaml", tracker=tracker)


if __name__ == '__main__':
    # Launch the async main function
    asyncio.run(main())
