# SolAgent

SolAgent is an intelligent agent system for generating Solidity smart contract code. This project includes baseline implementations, the main SolAgent system, and ablation study experiments.

## Project Structure

```
.
├── baseline_*.py              # Baseline agent implementations
├── main.py                    # Main SolAgent implementation
├── main_nopatch.py           # SolAgent main entrypoint
├── main_ablation_*.py        # Ablation study experiments
├── coding.yaml               # Code generation agent configuration
├── refine.yaml               # Refinement agent configuration
├── data/                     # Dataset files
├── output/                   # Output directory for results
├── db/                       # Database tracking modules
├── utils/                    # Utility modules
└── lib/                      # Third-party libraries (excluded from processing)
```

## Prerequisites

### Environment Setup

1. **Python Environment**: Python 3.8 or higher. Use separate Conda environments for different baseline/agent frameworks to avoid dependency conflicts.

2. **Initialize and Patch MS-Agent**:
   SolAgent depends on a patched version of `ms-agent`. Initialize the submodule at
   the recorded base commit, apply the project patch, and install it in editable
   mode before running experiments. Apply the patch on a clean checkout of the
   base commit; if the patch has already been applied, do not apply it again.
   ```bash
   git submodule update --init --recursive
   cd lib/ms-agent
   git checkout dd07b0d86e155ed5adb4a2d02185b592633324af
   git apply ../lib-agent2.patch
   cd ../..
   pip install -e lib/ms-agent
   ```

   The patch adds the custom `MyFileSystemTool`, Ollama backend support, tool
   registration changes, and LLM call handling required by SolAgent.

3. **Install Project Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Environment Variables**: Create a `.env` file in the project root with the following variables:
   ```bash
   OPENAI_API_KEY=your_openai_api_key
   OPENAI_BASE_URL=your_openai_base_url
   FORGE_PATH=/path/to/forge
   SLITHER_PATH=/path/to/slither
   ADERYN_BIN=/absolute/path/to/aderyn
   ORIG_REPO=/path/to/original/repository       # Required for main experiments
   ```

   **Note**: `ORIG_REPO` should point to the original repository path used in the dataset. This is used for path remapping.

5. **Dataset**: Ensure `data/dataset.json` exists with the required structure (file paths and their requirements/context). The source repository is shipped as `repository.7z`; extract it under the project root as `repository/`, and set up a copy at the path given by `ORIG_REPO`.

6. **Test Mapping**: Ensure `data/test_map_cargo.pkl` exists, which maps source files to their test file paths.

7. **External Tools**: The reported experiments use these fixed versions:

   - **Forge 0.3.0**: Solidity compilation and concrete testing
   - **Slither 0.11.3**: Primary static security analysis
   - **Aderyn 0.6.8**: Independent static-analysis validation
   - **Halmos 0.3.3**: RQ3 symbolic testing

   Halmos 0.3.3 requires Python 3.11 or newer. A separate environment avoids
   dependency conflicts with the generation frameworks:

   ```bash
   conda create -n halmos-py311 python=3.11 -y
   conda activate halmos-py311
   python -m pip install "halmos==0.3.3"
   export HALMOS_BIN="$(command -v halmos)"
   "$HALMOS_BIN" --version  # expected: halmos 0.3.3
   conda deactivate
   ```

   Verify Aderyn with `"$(command -v aderyn)" --version` and set its absolute
   path in `ADERYN_BIN`. The RQ3 runner reads `HALMOS_BIN`; equivalently, pass
   `--halmos-bin /absolute/path/to/halmos` on the command line.

## Running Experiments

### 1. Baseline Experiments

Run baseline agent implementations to generate comparison results:

#### DeepCode Baseline
```bash
python baseline_agent_deepcode.py
```

#### MetaGPT Baseline
```bash
python baseline_agent_metagpt.py
```

#### QwenAgent Baseline
```bash
python baseline_agent_qwenagent.py
```

#### GitHub Copilot Baseline
```bash
python baseline_agent_copilot.py
```

#### Vanillar LLM Baseline (Direct LLM API)
```bash
python baseline_rawmodel.py
```

#### Baseline Solidity Test (Original Files)
```bash
python baseline_sol_test.py
```
This script tests the original Solidity files from the dataset using Forge and Slither, providing a baseline for comparison. Results are stored in the `BaselineTest` table.

**Note**: Baseline results are stored in the database (`output/progress.db`) with agent-specific tracking tables. Each baseline script processes files from `data/dataset.json` and generates Solidity code according to the specified requirements.

### 2. SolAgent Main Experiment

Run the main SolAgent implementation:

```bash
python main_nopatch.py
```

This script:
- Uses `coding.yaml` for code generation agent configuration
- Uses `refine.yaml` for refinement agent configuration
- Stores results in `output/progress.db` using `ProgressTracker`
- Processes all files in the dataset and generates Solidity code
- Supports multiple models (configured in the script)
- Includes cost tracking and pause mechanisms

**Configuration Files**:
- `coding.yaml`: Defines the code generation agent (LLM model, system prompt, generation parameters)
- `refine.yaml`: Defines the refinement agent for code improvement

### 3. Ablation Studies

Run ablation experiments to study the impact of different components:

#### Ablation: No Forge Testing
```bash
python main_ablation_no_forge.py
```
This experiment removes Forge testing from the refinement process. Uses `refine_no_forge.yaml` configuration.

#### Ablation: No Slither Analysis
```bash
python main_ablation_no_slither.py
```
This experiment removes Slither static analysis from the refinement process. Uses `refine_no_slither.yaml` configuration.

#### Ablation: No Tools
```bash
python main_ablation_no_tools.py
```
This experiment removes all tools from the agent workflow. Uses `refine_no_tools.yaml` configuration.

**Note**: Ablation results are stored in `output/progress.db` using `ProgressTrackerAblation` in the `process_tracking_ablation` table with different `ablation_type` values:
- Type 2: No Forge
- Type 3: No Slither
- Type 4: No Tools

## Output and Results

All experiments store their results in SQLite database files located in the `output/` directory:

- **Database**: `output/progress.db`
- **Tables**: Different tracking tables for different experiment types
  - Baseline agents: Agent-specific tables
  - SolAgent: `process_tracking` table
  - Ablation studies: `process_tracking_ablation` table
  - Raw model baseline: `progress_tracker_rawmodel` table
  - Agent baselines: `progress_tracker_agent` table

### Viewing Results

Results can be queried from the database or analyzed using the statistics scripts in the `stats/` directory:

```bash
# Run specific statistics
python stats/rq1_statistics.py      # RQ1: legacy DB feedback-test/gas comparison
python stats/rq1_verify_eval_statistics.py  # RQ1: seed1 eval test-level correctness
python stats/rq1_security_statistics.py  # RQ1: SecurePass@1 and conditional security
python stats/rq1_security_slither_statistics.py  # RQ1: seed1 eval + Slither security
python stats/rq2_ablation_statistics.py  # RQ2: Ablation study
python stats/rq2_verify_eval_statistics.py  # RQ2: seed1 eval ablation correctness
python stats/rq3_symbolic_testing_statistics.py  # RQ3: Halmos symbolic testing
```

To run the hidden eval tests for RQ1 model outputs stored in `output/progress.db`, use `python testing/rq1_verify_eval_models.py`; the JSON report is written to `testing/eval/rq1_verify_eval_models.json`.
To run the hidden eval tests for RQ2 ablation outputs, use `python testing/rq2_verify_eval_ablation.py`; the JSON report is written to `testing/eval/rq2_verify_eval_ablation.json`.
Generate the corresponding paper-ready correctness table with
`python stats/rq2_verify_eval_statistics.py`; it is written to
`stats/eval/rq2_verify_eval_statistics.csv`.

To rerun the RQ3 Halmos experiment, use
`python testing/rq3_verify_symbolic_models.py`; the report is written to
`testing/symbolic/rq3_verify_symbolic_models.json`. Generate the paper table
with `python stats/rq3_symbolic_testing_statistics.py`; it is written to
`stats/symbolic/rq3_symbolic_testing_statistics.csv`.
RQ3 uses the same `test-first-security-second` checkpoint selection policy as
RQ1 and RQ2.

The legacy distillation script reads feedback tests from the database. To run
the independent eval on the 17 files excluded from distillation training and
generate its five-column table, use:

```bash
python testing/rq3_distill_verify_eval.py
python stats/rq3_distill_verify_eval_statistics.py
```

### Mimo SolAgent vs OpenCode

The `mimo-v2.5-pro` comparison uses the SolAgent rows in `output/progress.db`
and the 81 OpenCode artifacts under `baseline_opencode/result/mimo-v2.5-pro`.
Run the independent seed-1 eval and the paper-style tables with:

```bash
python testing/mimo_solagent_verify_eval.py
python testing/mimo_opencode_verify_eval.py
python stats/mimo_opencode_verify_eval_statistics.py
python stats/mimo_opencode_security_slither_statistics.py

python testing/rq3_verify_symbolic_models.py --db output/progress.db \
  --source solagent --model mimo-v2.5-pro \
  --selection-policy test-first-security-second \
  --report testing/symbolic/mimo_solagent_verify_symbolic.json
python testing/mimo_opencode_verify_symbolic.py
python stats/mimo_opencode_symbolic_testing_statistics.py
```

Aderyn is run separately on a machine with the scanner installed. The scan
runner and its table generator are intentionally separate:

```bash
python stats/ex_mimo_opencode_security_aderyn.py --aderyn-bin /path/to/aderyn
python stats/mimo_opencode_security_aderyn_statistics.py
```

### Reproducing the RQ1 Aderyn Security Results

The reported Aderyn results use **Aderyn 0.6.8** and a fixed Forge fuzz seed of
`0x0000000000000000000000000000000000000000000000000000000000000001`.
The scanner reads `output/progress.db` in read-only mode and writes per-sample
JSON files and aggregate results under `stats/aderyn/`; it does not update the
database.

Before running the experiment, set `ORIG_REPO` and the absolute Aderyn path in
`.env`:

```bash
ORIG_REPO=/absolute/path/to/original/repository
ADERYN_BIN=/absolute/path/to/aderyn
```

Verify that the configured binary is the required version:

```bash
"$(grep '^ADERYN_BIN=' .env | cut -d= -f2- | tr -d '\"')" --version
# Expected: aderyn 0.6.8
```

If the three committed eval reports under `testing/eval/` are available,
rerun every Aderyn scan from scratch and regenerate the paper table with:

```bash
python stats/ex_rq1_security_aderyn.py --timeout 300 --no-resume
python stats/rq1_security_aderyn_statistics.py
```

The scanner consumes these eval reports by default:

- `testing/eval/rq1_verify_eval_agents_seed1.json`
- `testing/eval/rq1_verify_eval_models_security_selected_seed1.json`
- `testing/eval/rq1_verify_eval_rawmodel_seed1.json`

For a complete reproduction starting from `output/progress.db`, first recreate
the eval reports. RawModel and baseline agents use `best-pass-first`; SolAgent
uses the experiment-time `test-first-security-second` selection policy:

```bash
SEED=0x0000000000000000000000000000000000000000000000000000000000000001

python testing/rq1_verify_eval_models.py \
  --source rawmodel \
  --selection-policy best-pass-first \
  --fuzz-seed "$SEED" \
  --report testing/eval/rq1_verify_eval_rawmodel_seed1.json

python testing/rq1_verify_eval_models.py \
  --source agent \
  --selection-policy best-pass-first \
  --fuzz-seed "$SEED" \
  --report testing/eval/rq1_verify_eval_agents_seed1.json

python testing/rq1_verify_eval_models.py \
  --source solagent \
  --selection-policy test-first-security-second \
  --fuzz-seed "$SEED" \
  --report testing/eval/rq1_verify_eval_models_security_selected_seed1.json

python testing/rq1_verify_eval_models.py \
  --source solagent-summary \
  --selection-policy test-first-security-second \
  --fuzz-seed "$SEED" \
  --report testing/eval/rq1_verify_eval_solagent_summary_seed1.json

python stats/rq1_verify_eval_statistics.py
python stats/ex_rq1_security_aderyn.py --timeout 300 --no-resume
python stats/rq1_security_aderyn_statistics.py
```

The test-level correctness table is written to
`stats/eval/rq1_verify_eval_statistics.csv`.

To regenerate only the tables from an existing `stats/aderyn/summary.json`, run:

```bash
python stats/rq1_security_aderyn_statistics.py
```

To compute the corresponding Slither table directly from the same fixed-seed
eval reports and the exact selected-round Slither results in `progress.db`, run:

```bash
python stats/rq1_security_slither_statistics.py --db output/progress.db
```

The output filename is derived from the script name, so this writes the
paper-ready table to `stats/slither/rq1_security_slither_statistics.csv`. It
does not rerun Slither or modify the database.

The paper-ready main table is written to
`stats/aderyn/rq1_security_aderyn_statistics.csv`.

#### Reproducing the RQ2 Cross-Analyzer Validation

RQ2 compares Full SolAgent with the `ablation_type=3` variant that does not
receive Slither feedback during refinement. Both variants use the same
experiment-time checkpoint rule: maximize feedback-test passes, minimize
offline Slither H+M+L findings only among identical `(passed,total)` ties, and
then keep the earliest round.

The cross-analyzer experiment uses these pinned tools:

- [Aderyn](https://github.com/Cyfrin/aderyn) 0.6.8

The committed `testing/eval/rq2_verify_eval_ablation.json` can be reused. To
regenerate it with the fixed seed, run:

```bash
python testing/rq2_verify_eval_ablation.py \
  --selection-policy test-first-security-second \
  --fuzz-seed 0x0000000000000000000000000000000000000000000000000000000000000001
```

```bash
python stats/ex_rq2_security_aderyn.py \
  --timeout 300 --no-rq1-reuse --no-resume
python stats/rq2_security_cross_analyzer_statistics.py
```

To reproduce each analyzer independently, use separate feedback/eval entry
points, matching the two Slither statistics scripts:

```bash
python stats/rq2_security_aderyn_statistics_feedback.py
python stats/rq2_security_aderyn_statistics_eval.py
```

Each script writes `statistics_feedback.{json,csv}` or
`statistics_eval.{json,csv}` under its analyzer's `stats/<analyzer>/rq2/`
directory. The cross-analyzer script is an optional combined view, not the
only reproduction entry point.

The paper tables, paired tests, analyzer ranking, and scan-coverage audit are
written under `stats/rq2_cross_analyzer/`. Reproduce the same-tool Slither
feedback and independent-eval tables separately with:

```bash
python stats/rq2_slither_feedback_statistics_feedback.py
python stats/rq2_slither_feedback_statistics_eval.py
```

## Distillation Training

This project supports knowledge distillation training to create smaller, efficient models based on the SolAgent results. The distillation process consists of two steps: data processing and model training.

### Step 1: Data Processing

Process the experimental results from the database to generate training datasets:

```bash
python z0train/data_processor.py
```

### Step 2: Model Training

Train a distilled model using the processed data:

#### Stage 1: Right Truncation (First 4K tokens)

```bash
python z0train/train_sft_swift.py \
  --model_name_or_path Qwen/Qwen3-8B \
  --data_path z0train/output/processed_tracker.json \
  --output_dir z0train/output/stage1-right-4k \
  --stage 1 \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 \
  --gradient_accumulation_steps 2 \
  --learning_rate 2e-5 \
  --max_length 16384 \
  --gradient_checkpointing \
  --bf16
```

**Key Parameters**:
- `--model_name_or_path`: Base model to fine-tune (Qwen/Qwen3-8B, supports ModelScope model IDs)
- `--data_path`: Path to processed training data
- `--output_dir`: Directory to save checkpoints
- `--stage 1`: Right truncation mode (keeps first 4K tokens)
- `--max_length`: Maximum sequence length (16384 for 4K context)
- `--gradient_checkpointing`: Enable gradient checkpointing to save memory
- `--bf16`: Use bfloat16 precision for training

#### Stage 2: Left Truncation (Last 4K tokens, Continue from Stage 1)

After Stage 1 completes, continue training with left truncation:

```bash
python z0train/train_sft_swift.py \
  --model_name_or_path Qwen/Qwen3-8B \
  --data_path z0train/output/processed_tracker.json \
  --output_dir z0train/output/stage2-left-4k \
  --stage 2 \
  --stage1_checkpoint z0train/output/stage1-right-4k \
  --num_train_epochs 3 \
  --per_device_train_batch_size 1 \
  --gradient_accumulation_steps 2 \
  --learning_rate 2e-5 \
  --max_length 16384 \
  --gradient_checkpointing \
  --bf16
```

**Key Parameters**:
- `--stage 2`: Left truncation mode (keeps last 4K tokens)
- `--stage1_checkpoint`: Path to Stage 1 checkpoint directory

## Statistics and Analysis

- `stats/ex_rq1_*.py`: Supplementary statistics (LOC, Token usage, Gas analysis)
