import asyncio
import json
import os
import sys
from typing import Dict, Any

from db.summary_tracker import SummaryTracker
from tools.summary import CodeSummaryGenerator
from utils.cost_calculator import CostCalculator

async def process_file(
    file_path: str,
    file_content: list,
    tracker: SummaryTracker,
    summary_generator: CodeSummaryGenerator,
    cost_calculator: CostCalculator
):
    """Process a single file to generate summary."""

    # if file_path != "repository/openzeppelin-contracts/contracts/utils/cryptography/P256.sol":
    #     return
    
    # Check if already processed
    existing_summary = tracker.get_summary(file_path)
    if existing_summary:
        print(f"[SKIP] Summary already exists for: {file_path}")
        return

    # Build query from file content
    # Assuming file_content is a list of classes/contracts as per previous context
    if not file_content or not isinstance(file_content, list):
        print(f"[SKIP] Invalid content for: {file_path}")
        return

    query_dict = {}
    verify_dict = {}

    for cls in file_content:
        # kind = cls.get('kind', 'contract')
        identifier = cls.get('identifier', 'Unknown')
        # file_class = f"\n{kind} {identifier}\n"
        # query += file_class
        
        query = ""
        methods = cls.get("methods", [])
        verify_methods = []
        for method in methods:
            if method.get("kind") not in ["struct", "function", "constructor"]:
                continue

            full_signature = method.get("full_signature", "").strip()
            human_labeled_comment = method.get("human_labeled_comment", "").strip()

            verify_methods.append(full_signature)
            
            if full_signature:
                prefix = "\n" if query else ""
                query += f"""{prefix}{human_labeled_comment}
{full_signature}
"""
        query_dict[identifier] = query
        verify_dict[identifier] = verify_methods

    if not query.strip():
        print(f"[SKIP] No queryable content for: {file_path}")
        return

    print(f"[PROCESSING] Generating summary for: {file_path} (classes: {len(file_content)})")
    
    # Generate summary
    try:
        summary_dict = {}
        prompt_tokens = 0
        completion_tokens = 0
        model_name = summary_generator.model
        for identifier, query in query_dict.items():
            # Call with return_usage=True
            result = summary_generator.generate_summary_and_prompt(query, return_usage=True)
        
            if result:
                summary_text = result['choices'][0]['message']['content']
                usage = result.get('usage')
                prompt_tokens += usage.get("prompt_tokens", 0)
                completion_tokens += usage.get("completion_tokens", 0)
                summary_dict[identifier] = summary_text

                # verify
                expected_methods = verify_dict.get(identifier, [])
                # split summary into lines and check, remove empty lines
                summary_lines = []
                for line in summary_text.splitlines():
                    s = line.strip()
                    if not s:
                        continue
                    if ':' in s:
                        s = s.split(':', 1)[0].strip()
                    summary_lines.append(s)
                for i, method_sig in enumerate(expected_methods):
                    if (method_sig.startswith("function") and not method_sig.endswith(summary_lines[i])) or (not method_sig.startswith("function") and method_sig != summary_lines[i]):
                        print(f"[WARNING] Mismatch in summary for {identifier}: expected method signature not found:\nExpected: {method_sig}\nFound: {summary_lines[i] if i < len(summary_lines) else 'N/A'}")
                        return

        if summary_dict:    
            # Calculate cost
            cost = cost_calculator.calculate_cost(model_name, prompt_tokens, completion_tokens)
                
            print(f"[COST] Summary generation: ${cost:.6f} ({prompt_tokens}+{completion_tokens} tokens)")
            
            # Save to DB
            tracker.add_or_update_summary(
                file_path=file_path,
                summary_text=json.dumps(summary_dict),
                model_name=model_name,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens
            )
            print(f"[COMPLETED] Saved summary for: {file_path}")
            
        else:
            print(f"[ERROR] Failed to generate summary for: {file_path}")

    except Exception as e:
        print(f"[ERROR] Exception processing {file_path}: {e}")


async def main():
    path = os.path.dirname(os.path.abspath(__file__))
    dataset_path = os.path.join(path, 'data/dataset.json')
    
    if not os.path.exists(dataset_path):
        print(f"Dataset not found at: {dataset_path}")
        return

    with open(dataset_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Initialize components
    tracker = SummaryTracker(db_path=os.path.join(path, "output", "progress.db"))
    
    # Ensure output directory exists
    os.makedirs(os.path.join(path, "output"), exist_ok=True)

    cost_calculator = CostCalculator(price_file=os.path.join(path, "data/price.json"))
    
    summary_model_name = "gpt-5-mini"
    summary_generator = CodeSummaryGenerator(model_name=summary_model_name) 
    print(f"Using model: {summary_generator.model}")

    # Process files
    
    total_files = len(data)
    print(f"Found {total_files} files to process.")
    
    for i, file_path in enumerate(data):
        print(f"--- File {i+1}/{total_files} ---")
        await process_file(
            file_path=file_path,
            file_content=data[file_path],
            tracker=tracker,
            summary_generator=summary_generator,
            cost_calculator=cost_calculator
        )

    tracker.close()
    print("\n[INFO] Summary generation process finished.")

if __name__ == "__main__":
    asyncio.run(main())