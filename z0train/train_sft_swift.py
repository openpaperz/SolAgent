#!/usr/bin/env python3
"""
SFT Training Script
Uses Alibaba SWIFT framework for SFT training
"""

import copy
import json
import logging
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from transformers import AutoTokenizer

try:
    from swift.llm import sft_main
    from swift.utils import get_logger
    except Exception as exc:  # pragma: no cover - import guard
        raise RuntimeError(
            "SWIFT is not installed or unavailable. Please install Alibaba SWIFT dependencies before running this script."
        ) from exc

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = get_logger()


@dataclass
class DataArguments:
    """Data-related arguments"""
    data_path: str = field(
        default="output/processed_tracker.json",
        metadata={"help": "Training data path"}
    )
    max_seq_length: int = field(
        default=16384,
        metadata={"help": "Maximum sequence length"}
    )
    stage: int = field(
        default=1,
        metadata={"help": "Training stage: 1=right truncation (first 4K), 2=left truncation (last 4K, continue from stage1)"}
    )
    stage1_checkpoint: Optional[str] = field(
        default=None,
        metadata={"help": "Stage1 model checkpoint path (only used when stage=2)"}
    )


def load_data(data_path: str) -> List[Dict[str, Any]]:
    """Load processed data"""
    logger.info(f"Loading data from {data_path}")

    with open(data_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    logger.info(f"Loaded {len(data)} samples")
    return data


def normalize_messages(messages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Normalize message format to ensure tool_calls field structure is consistent"""
    for msg in messages:
        tool_calls = msg.get("tool_calls")
        if not tool_calls:
            continue

        for tc in tool_calls:
            fn = tc.get("function") if isinstance(tc.get("function"), dict) else {}

            # Unify arguments: dict -> JSON str, None -> ""
            arguments = fn.get("arguments", tc.get("arguments"))
            if isinstance(arguments, dict):
                arguments = json.dumps(arguments, ensure_ascii=False)
            elif arguments is None:
                arguments = ""

            # Ensure function structure is complete
            fn.setdefault("name", tc.get("name", ""))
            fn["arguments"] = arguments
            tc["function"] = fn

            # Top-level fields also keep as strings to avoid Arrow type inference issues
            tc["arguments"] = arguments
            tc["name"] = tc.get("name", fn.get("name", ""))

    return messages


def prepare_dataset(
    data: List[Dict[str, Any]],
    train_ratio: float = 0.8,
    model_name: Optional[str] = None,
    max_length: int = 65536,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Prepare data and split train/validation sets by source_file

    Split by source_file groups to ensure samples from the same source_file don't appear in both train and validation sets.
    Also use Tokenizer to accurately calculate token count and filter out samples exceeding max_length.
    """
    
    # Load Tokenizer for accurate length calculation
    tokenizer = None
    if model_name:
        try:
            logger.info(f"Loading tokenizer from {model_name} for length filtering...")
            tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
        except Exception as e:
            logger.warning(f"⚠️ Failed to load tokenizer: {e}. Will fallback to char approximation.")

    # Deep copy and normalize data to avoid modifying original data
    normalized_data = []
    dropped_count = 0
    
    for idx, sample in enumerate(data):
        messages = sample.get('messages', [])
        
        # Calculate length
        length = 0
        if tokenizer:
            try:
                # Use apply_chat_template to calculate the most accurate token count
                input_ids = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=False)
                length = len(input_ids)
            except Exception as e:
                # Template application failed, fallback to simple estimation (char / 3)
                total_chars = sum(len(str(m.get('content', ''))) for m in messages)
                length = total_chars // 3
        else:
             # Fallback estimation without Tokenizer (char / 3)
            total_chars = sum(len(str(m.get('content', ''))) for m in messages)
            length = total_chars // 3

        if length > max_length:
            dropped_count += 1
            if dropped_count <= 5: # Only print first few filtered samples to avoid spam
                logger.info(f"   Drop sample {idx} (src: {sample.get('source_file')}), length: {length} > {max_length}")
            continue

        sample_copy = copy.deepcopy(sample)
        sample_copy["messages"] = normalize_messages(sample_copy["messages"])
        # tools may be empty list, keep consistency
        sample_copy["tools"] = sample_copy.get("tools", []) or []
        normalized_data.append(sample_copy)

    if dropped_count > 0:
        logger.warning(f"⚠️  Dropped {dropped_count} samples exceeding token limit ({max_length})")
        logger.warning("   (Dropping is better than truncating for tool-use/JSON consistency)")

    data = normalized_data

    # Group by source_file
    import random
    from collections import defaultdict

    file_groups = defaultdict(list)
    for idx, sample in enumerate(data):
        source_file = sample.get("source_file", "unknown")
        file_groups[source_file].append(idx)

    # Get all source_file list and shuffle randomly
    source_files = list(file_groups.keys())
    random.seed(42)
    random.shuffle(source_files)

    # Split source_file by ratio
    num_train_files = int(len(source_files) * train_ratio)
    train_files = set(source_files[:num_train_files])
    eval_files = set(source_files[num_train_files:])

    logger.info(f"Total unique source files: {len(source_files)}")
    logger.info(f"Train files: {len(train_files)}, Eval files: {len(eval_files)}")

    # Save train_files to file for later use
    script_dir = Path(__file__).parent
    output_dir = script_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    train_files_path = output_dir / "train_files.json"
    with open(train_files_path, 'w', encoding='utf-8') as f:
        json.dump(list(train_files), f, ensure_ascii=False, indent=2)
    logger.info(f"✅ Train files saved to {train_files_path}")

    if model_name:
        model_name_normalized = model_name.replace("/", "_")
        train_files_dir = script_dir / "train_files"
        train_files_dir.mkdir(parents=True, exist_ok=True)
        model_train_files_path = train_files_dir / f"{model_name_normalized}.json"
        with open(model_train_files_path, 'w', encoding='utf-8') as f:
            json.dump(list(train_files), f, ensure_ascii=False, indent=2)
        logger.info(f"✅ Train files saved to {model_train_files_path}")

    # Assign samples based on source_file
    train_indices = []
    eval_indices = []

    for source_file, indices in file_groups.items():
        if source_file in train_files:
            train_indices.extend(indices)
        else:
            eval_indices.extend(indices)

    # Create training and validation sets
    train_data = [data[i] for i in train_indices]
    eval_data = [data[i] for i in eval_indices]

    logger.info(f"✅ Train samples: {len(train_data)}")
    logger.info(f"✅ Eval samples: {len(eval_data)}")

    return train_data, eval_data


def save_dataset_jsonl(data: List[Dict[str, Any]], output_path: str) -> None:
    """Save dataset as JSONL format for SWIFT use"""
    with open(output_path, 'w', encoding='utf-8') as f:
        for sample in data:
            json.dump(sample, f, ensure_ascii=False)
            f.write("\n")

    logger.info(f"✅ Dataset saved to {output_path}")
    logger.info(f"   Total samples: {len(data)}")


def prepare_datasets(
    data_args: DataArguments,
    model_name_or_path: Optional[str] = None,
) -> Tuple[str, str]:
    """Prepare training/validation data and save as JSONL"""
    data = load_data(data_args.data_path)
    train_data, eval_data = prepare_dataset(
        data, 
        model_name=model_name_or_path,
        max_length=data_args.max_seq_length
    )

    # Validate data format (check tool_calls)
    sample_with_tools = next((s for s in data if any(m.get("tool_calls") for m in s["messages"])), None)
    if sample_with_tools:
        tool_msg_count = sum(1 for s in data for m in s["messages"] if m.get("tool_calls"))
        logger.info(f"✅ Found {tool_msg_count} messages with tool_calls")
        logger.info(f"   Sample message with tool_calls: {sample_with_tools['messages'][0].get('role', 'N/A')}")

    script_dir = Path(__file__).parent
    output_dir = script_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    train_jsonl = output_dir / "train_dataset.jsonl"
    eval_jsonl = output_dir / "eval_dataset.jsonl"

    save_dataset_jsonl(train_data, str(train_jsonl))
    save_dataset_jsonl(eval_data, str(eval_jsonl))

    return str(train_jsonl), str(eval_jsonl)


def build_swift_args(
    model_path: str,
    train_jsonl: str,
    eval_jsonl: str,
    output_dir: str,
    args: Any,
) -> List[str]:
    """Build SWIFT training arguments list"""
    swift_args = [
        "--model", model_path,
        "--dataset", train_jsonl,
        "--val_dataset", eval_jsonl,
        "--output_dir", output_dir,
        "--num_train_epochs", str(args.num_train_epochs),
        "--per_device_train_batch_size", str(args.per_device_train_batch_size),
        "--per_device_eval_batch_size", str(args.per_device_eval_batch_size),
        "--gradient_accumulation_steps", str(args.gradient_accumulation_steps),
        "--learning_rate", str(args.learning_rate),
        "--max_length", str(args.max_length),
        "--save_steps", str(args.save_steps),
        "--eval_steps", str(args.eval_steps),
        "--logging_steps", str(args.logging_steps),
        "--save_total_limit", "3",
        "--eval_strategy", "steps",
        "--save_strategy", "steps",
        "--load_best_model_at_end", "true",
        "--metric_for_best_model", "loss",
        "--report_to", "none",
        "--train_type", "lora" if args.use_lora else "full",
        "--sequence_parallel_size", "8",
    ]

    if getattr(args, "attn_impl", None):
        swift_args.extend(["--attn_impl", str(args.attn_impl)])

    if args.use_lora:
        swift_args.extend([
            "--lora_rank", str(args.lora_rank),
            "--lora_alpha", str(args.lora_alpha),
            "--lora_dropout", "0.05",
            #"--lora_target_modules", "q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj",
        ])

    if args.gradient_checkpointing:
        swift_args.extend(["--gradient_checkpointing", "true"])

    if args.bf16:
        swift_args.extend(["--bf16", "true"])
    elif args.fp16:
        swift_args.extend(["--fp16", "true"])

    return swift_args


def main() -> None:
    """Main function"""
    import argparse

    parser = argparse.ArgumentParser(description="SWIFT SFT Training")
    parser.add_argument("--model_name_or_path", type=str, default="Qwen/Qwen3-4B-Instruct-2507", help="Model path")
    parser.add_argument("--data_path", type=str, default="output/processed_tracker.json", help="Data path")
    parser.add_argument("--output_dir", type=str, default="output/pxcoder-test1", help="Output path")
    parser.add_argument("--stage", type=int, default=1, help="Training stage: 1=right truncation, 2=left truncation")
    parser.add_argument("--stage1_checkpoint", type=str, default=None, help="Stage1 checkpoint path")
    parser.add_argument("--num_train_epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--per_device_train_batch_size", type=int, default=1, help="Training batch size")
    parser.add_argument("--per_device_eval_batch_size", type=int, default=1, help="Evaluation batch size")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=2, help="Gradient accumulation steps")
    parser.add_argument("--learning_rate", type=float, default=2e-5, help="Learning rate")
    parser.add_argument("--max_length", type=int, default=256*1024, help="Maximum sequence length")
    parser.add_argument("--save_steps", type=int, default=36, help="Save steps")
    parser.add_argument("--eval_steps", type=int, default=36, help="Evaluation steps")
    parser.add_argument("--logging_steps", type=int, default=10, help="Logging steps")
    parser.add_argument("--attn_impl", type=str, default=None, help="Attention implementation, e.g., flash_attn")
    parser.add_argument("--use_lora", action="store_true", help="Whether to use LoRA")
    parser.add_argument("--lora_rank", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora_alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--gradient_checkpointing", action="store_true", help="Whether to enable gradient checkpointing")
    parser.add_argument("--bf16", default=True, action="store_true", help="Whether to use bf16")
    parser.add_argument("--fp16", action="store_true", help="Whether to use fp16")

    args = parser.parse_args()

    # Stage 2: Continue training from Stage 1 checkpoint
    model_path = args.model_name_or_path
    if args.stage == 2 and args.stage1_checkpoint:
        logger.info(f"📂 Stage 2 will load from Stage 1 checkpoint: {args.stage1_checkpoint}")
        model_path = args.stage1_checkpoint
    else:
        # Try to download model using ModelScope
        try:
            from modelscope import snapshot_download
            if not os.path.exists(model_path):
                logger.info(f"Downloading model {model_path} from ModelScope...")
                model_path = snapshot_download(model_path)
                logger.info(f"Model downloaded to: {model_path}")
        except Exception as e:
            logger.warning(f"ModelScope check failed: {e}")

    # Prepare data
    data_args = DataArguments(
        data_path=args.data_path,
        stage=args.stage,
        stage1_checkpoint=args.stage1_checkpoint,
        max_seq_length=args.max_length,
    )
    train_jsonl, eval_jsonl = prepare_datasets(data_args, model_name_or_path=model_path)

    # Build SWIFT training arguments and start training
    swift_args = build_swift_args(
        model_path=model_path,
        train_jsonl=train_jsonl,
        eval_jsonl=eval_jsonl,
        output_dir=args.output_dir,
        args=args,
    )

    logger.info("\n" + "=" * 80)
    logger.info("🏃 Starting SWIFT training")
    logger.info("=" * 80 + "\n")

    sys.argv = ["train_sft_swift.py"] + swift_args
    sft_main()

    logger.info("\n" + "=" * 80)
    logger.info(f"🎉 Training completed successfully! Stage {args.stage}")
    logger.info("=" * 80)

    if args.stage == 1:
        logger.info("\n" + "=" * 80)
        logger.info("💡 Stage 1 completed! You can now start Stage 2 to continue training:")
        logger.info(f"   python z0train/train_sft_swift.py \\")
        logger.info(f"     --stage 2 \\")
        logger.info(f"     --stage1_checkpoint {args.output_dir} \\")
        logger.info(f"     --output_dir z0train/output/stage2-left-4k \\")
        logger.info(f"     --num_train_epochs 3")
        logger.info("=" * 80)


if __name__ == "__main__":
    main()
