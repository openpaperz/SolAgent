from utils.feedback_utils import generate_feedback
from utils.forge_utils import run_forge_test
import pickle
import copy
import json
import os
import re
import subprocess
from contextlib import contextmanager
from typing import List, Optional
import difflib

from omegaconf import DictConfig

from file_parser import extract_code_blocks
from ms_agent.agent.runtime import Runtime
from ms_agent.callbacks import Callback
from ms_agent.llm.utils import Message
from ms_agent.tools.myfilesystem_tool import MyFileSystemTool
from ms_agent.utils import get_logger
from utils.shared_context import shared_context
from utils.slither_utils import run_slither, get_slither_feedback_and_count
from db.baseline_test import BaselineTest

logger = get_logger()

# callback order: on_generate_response, [get assistant], on_tool_call, after_tool_call
class EvalCallback(Callback):
    """Eval the code by compiling and human eval.
    """

    def __init__(self, config: DictConfig):
        super().__init__(config)
        self.is_patch = config.get("patch", False)
        self.enable_forge = config.get("forge", True)
        self.enable_slither = config.get("slither", True)

        # control using which improved token prune strategy
        self.token_prune_strategy = "improved1"
        self.best_changed = False

        self.feedback_ended = False
        # self.file_system = MyFileSystemTool(config)
        self.compile_round = 66
        self.cur_round = 1
        self.last_issue_length = 0

        self.all_passed_vuln_round = 0
        self.best_vuln_count = 0
        
        # Track compile errors and feedback similarity
        self.compile_error_count = 0
        self.last_feedback = None
        self._round_feedbacks = {}  # Track feedback per round for idempotency

        orig_sol, cur_t_sol, cur_sol = shared_context.get_all()
        self.cur_sol = cur_sol
        self.cur_t_sol = cur_t_sol

        # Prefer the file_path stored in shared_context (relative path as saved in main.py)
        file_path_ctx = None
        try:
            file_path_ctx = shared_context.get_file_path()
        except Exception:
            file_path_ctx = None

        if file_path_ctx:
            self.file_path = file_path_ctx

        # Read checkpoint meta (table_name, entry_id) for building checkpoint paths
        self.table_name, self.entry_id = shared_context.get_checkpoint_meta()
        self.output_dir = config.get("output_dir", "output")
        if not os.path.isabs(self.output_dir):
            self.output_dir = os.path.join(os.getcwd(), self.output_dir)
        self.checkpoint_path = None
        if self.table_name and self.entry_id:
            self.checkpoint_path = os.path.join(self.output_dir, f"{self.table_name}{self.entry_id}.pkl")

        self.best_code: Optional[str] = None  # Current best code
        
        # Initialize baseline_test tracker for reading vuln_count
        self.baseline_tracker = BaselineTest(db_path=os.path.join(self.output_dir, "progress.db"))

        #todo: If code agent code fails to compile, refine attempts to fix until test results are available then stop; if code agent code passes tests, if 100% then don't refine, otherwise refine until pass count improves then stop, if no improvement for two rounds also stop.
        self.best_passed = -1          # Current maximum pass count
        self.total_tests = 0           # Current total test count
        self.no_improve_rounds = 0     # Consecutive rounds without improvement

        self.origin_messages = None # record all distinct messages across interactions
        self.round_messages = {} # record messages per round
        self.round_summaries = {}  # record per-round test summaries: {round: {passed, failed, total, ...}}
        
        # Idempotency tracking
        self._last_issue_lengths = {}
        self._compiled_rounds = set()

        # Try to restore EvalCallback state from checkpoint if available
        try:
            if self.checkpoint_path and os.path.exists(self.checkpoint_path):
                with open(self.checkpoint_path, "rb") as cf:
                    state = pickle.load(cf)
                # Restore primitive fields
                for k in [
                    "cur_round", "compile_round", "best_passed", "total_tests",
                    "no_improve_rounds", "last_issue_length", "best_changed",
                    "feedback_ended", "all_passed_vuln_round", "best_vuln_count",
                    "compile_error_count", "last_feedback"
                ]:
                    if k in state:
                        setattr(self, k, state[k])
                # Restore best_code
                if "best_code" in state:
                    self.best_code = state["best_code"]
                # Restore messages
                if "origin_messages" in state and isinstance(state["origin_messages"], list):
                    try:
                        self.origin_messages = [Message(**m) for m in state["origin_messages"]]
                    except Exception:
                        self.origin_messages = None
                if "round_messages" in state and isinstance(state["round_messages"], dict):
                    restored = {}
                    for rk, rv in state["round_messages"].items():
                        try:
                            restored[int(rk)] = [Message(**m) for m in rv]
                        except Exception:
                            restored[int(rk)] = rv
                    self.round_messages = restored
                # Restore summaries
                if "round_summaries" in state and isinstance(state["round_summaries"], dict):
                    self.round_summaries = state["round_summaries"]
                
                # Restore idempotency fields
                if "_compiled_rounds" in state:
                    self._compiled_rounds = set(state["_compiled_rounds"])
                
                if "_last_issue_lengths" in state:
                    self._last_issue_lengths = state["_last_issue_lengths"]
                
                if "_round_feedbacks" in state:
                    self._round_feedbacks = state["_round_feedbacks"]

                print(f"[RESTORE] EvalCallback state from {self.checkpoint_path}")
        except Exception as e:
            print(f"[WARNING] Failed to restore EvalCallback checkpoint: {e}")

    async def on_task_begin(self, runtime: Runtime, messages: List[Message]):
        # Restore messages from the last round if available (resume logic)
        if self.round_messages:
            try:
                last_round = max(self.round_messages.keys())
                if last_round in self.round_messages:
                    print(f"[RESTORE] Resuming messages from round {last_round}")
                    messages.clear()
                    messages.extend(self.round_messages[last_round])

                    # Extract and write code from the last assistant message
                    wrote_code = False
                    for msg in reversed(messages):
                        if hasattr(msg, 'role') and msg.role == 'assistant' and not msg.tool_calls:
                            if hasattr(msg, 'content') and msg.content:
                                all_files, _ = extract_code_blocks(msg.content)
                                for file in all_files:
                                    code = file.get("code")
                                    if code:
                                        with open(self.cur_sol, "w") as f:
                                            f.write(code)
                                        print(f"[RESTORE] Wrote code to {self.cur_sol}")
                                        wrote_code = True
                                        break
                            if wrote_code:
                                break
            except Exception as e:
                print(f"[WARNING] Failed to restore messages in on_task_begin: {e}")

        #-- modify system message role to developer for gpt5 reasoning model
        if self.config.llm.model.startswith("gpt-5") and messages[0].role == 'system':
            system_message = messages[0]
            system_message.role = "developer"
            system_message.content = "# Juice: 0 !important\n" + system_message.content
        #----

        if self.origin_messages is None:
            self.origin_messages = copy.deepcopy(messages)

        if not self.round_messages:
            self.omit_intermediate_messages(messages)
        # await self.file_system.connect()

    def omit_intermediate_messages(self, messages: List[Message]):
        if self.token_prune_strategy == "improved1":
            tmp = messages[:3]
            if self.last_issue_length > 0:
                last_issue_messages = messages[-self.last_issue_length:]
                self.origin_messages.extend(copy.deepcopy(last_issue_messages))

                tmp += last_issue_messages
                m = messages[-self.last_issue_length-2]
                if m.role == 'assistant' and not m.tool_calls:
                    tmp[2] = m # non patch mode
                    # if is patch mode, fill the m content with temp.sol
                    if self.is_patch:
                        # In patch mode, replace tmp[2].content with temp.sol content
                        output_dir = self.config.get("output_dir", "output")
                        if not os.path.isabs(output_dir):
                            output_dir = os.path.join(os.getcwd(), output_dir)
                        temp_sol_path = os.path.join(output_dir, "temp.sol")
                        
                        if os.path.exists(temp_sol_path):
                            with open(temp_sol_path, 'r') as f:
                                temp_content = f.read()
                            filename = os.path.basename(self.cur_sol)
                            tmp[2].content = f"```solidity: {filename}\n{temp_content}\n```"
                        
            messages.clear()
            messages.extend(tmp)

            # guard against short message lists to avoid IndexError
            if len(messages) > 2:
                messages[2].tool_calls = None
        elif self.token_prune_strategy == "improved2":
            tmp = messages[:3]
            if self.last_issue_length > 0:
                last_issue_messages = messages[-self.last_issue_length:]
                self.origin_messages.extend(copy.deepcopy(last_issue_messages))

                if self.best_changed:
                    tmp += last_issue_messages
                    m = messages[-self.last_issue_length-2]
                    if m.role == 'assistant' and not m.tool_calls:
                        tmp[2] = m
                else:
                    start_mid = 2
                    end_mid = len(messages) - self.last_issue_length - 2
                    if end_mid < start_mid:
                        end_mid = start_mid

                    # add middle context if any
                    tmp += messages[start_mid:end_mid]

                    # find the last assistant message (without tool_calls) before the failing block
                    last_no_toolcall_idx = None
                    search_end = len(messages) - self.last_issue_length - 1
                    for i in range(search_end, 1, -1):
                        m = messages[i]
                        if m.role == 'assistant' and not m.tool_calls:
                            last_no_toolcall_idx = i
                            break

                    if last_no_toolcall_idx is not None:
                        # include from that assistant turn up to the start of failing block
                        tmp += messages[last_no_toolcall_idx:]
                
            messages.clear()
            messages.extend(tmp)

            # guard against short message lists to avoid IndexError
            if len(messages) > 2:
                messages[2].tool_calls = None

    @contextmanager
    def chdir_context(self):
        path = os.getcwd()
        work_dir = "/".join(self.cur_t_sol.split('/')[0:3])
        if not path.endswith(work_dir):
            os.chdir(work_dir)
            yield
            os.chdir(path)
        else:
            yield

    @staticmethod
    def _parse_e_msg(e):
        stdout = None
        stderr = None
        if hasattr(e, 'stdout'):
            stdout = e.stdout
            if hasattr(stdout, 'decode'):
                stdout = stdout.decode('utf-8')
        if hasattr(e, 'stderr'):
            stderr = e.stderr
            if hasattr(stderr, 'decode'):
                stderr = stderr.decode('utf-8')
        result = ''
        if stdout or stderr:
            result += (stdout or '') + '\n' + (stderr or '')
        else:
            result += str(e)
        return result

    @staticmethod
    def check_gas():
        pass

    @staticmethod
    def parse_gas_stdout():
        pass

    def check_forge(self):
        work_dir = "/".join(self.cur_t_sol.split('/')[0:-1])
        match_path = self.cur_t_sol.split('/')[-1]

        # Read forge binary path from environment variable FORGE_PATH (no default)
        try:
            forge_bin = os.environ['FORGE_PATH']
        except KeyError:
            raise RuntimeError("Environment variable FORGE_PATH is not set. Please set it (e.g. in .env) before running.")

        test_process = subprocess.run([forge_bin, 'test', '--match-path', f'{match_path}'], capture_output=True, cwd=work_dir, timeout=120) # --match-test testPack
        captured_stdout = test_process.stdout.decode()

        return captured_stdout

    def parse_forge_stdout(self, captured_stdout):
        # Check if compiler output contains "Compiler run failed:", if error return error message directly
        if "Compiler run failed" in captured_stdout:
            return {"compile_error": captured_stdout}

        # debug: Extract passed, failed, total using regex
        pattern_d = r":\s*(\d+)\s*tests\s*passed,\s*(\d+)\s*failed.*?\((\d+)\s*total\s*tests\)"
        match_d = re.search(pattern_d, captured_stdout)
        summary = None
        if match_d:
            passed = int(match_d.group(1))
            failed = int(match_d.group(2))
            total = int(match_d.group(3))
            print(f"round {self.cur_round}: passed={passed}, failed={failed}, total={total}")
            summary = {"passed": passed, "failed": failed, "total": total}
        else:
            # If no summary, still try to extract failing-tests section
            passed = failed = total = None

        # Extract part after "Failing tests:"
        fails_dict = {}
        parts = re.split(r"Failing tests:\s*", captured_stdout, maxsplit=1)
        # if len(parts) < 2:
        #     print("No 'Failing tests:' section found.")
        #     return None
        if len(parts) >= 2:
            section = parts[1]

            # Match complete [FAIL: ...] line, capture test name and full line content (remove runs part)
            pattern = re.compile(
                r"^\[FAIL:[^\n]*?\]\s+([a-zA-Z0-9_]+\(.*?\))\s*(?:\(runs:.*)?$", re.MULTILINE
            )

            for match in pattern.finditer(section):
                full_line = match.group(0)
                test_name = match.group(1)
                # Remove trailing runs information
                cleaned_line = re.sub(r"\(runs:.*", "", full_line).strip()
                fails_dict[test_name] = cleaned_line

        # 4) Organize return value: prioritize returning summary + fails (if summary exists)
        if summary is not None:
            summary["fails"] = fails_dict
            return summary

        # 5) If no summary but has fails (or no useful information parsed), return original output as error message or return failure details
        if fails_dict:
            return {"passed": 0, "failed": len(fails_dict), "total": None, "fails": fails_dict}

        # 6) Fallback: return original output as compile_error (or unparsed information)
        return {"compile_error": captured_stdout}

    def _write_best_and_memory(self):
        """Internal helper to write the best code and memory artifacts to disk.

        Separated out so it can be reused from other callbacks (e.g. on_generate_response).
        """
        # write the best code to cur_sol
        if self.best_code:
            with open(self.cur_sol, "w") as f:
                f.write(self.best_code)
            print(f"[EVAL] Wrote best code with {self.best_passed}/{self.total_tests} tests passed to {self.cur_sol}.")

        origin_message_path = os.path.join(self.config["output_dir"], "memory/messages.json")
        with open(origin_message_path, "w") as f:
            json.dump([message.to_dict() for message in self.origin_messages], f, ensure_ascii=False)

        round_messages_path = os.path.join(self.config["output_dir"], "memory/round_messages.json")
        round_msgs_serializable = {
            str(round_num): [msg.to_dict() for msg in msgs] for round_num, msgs in self.round_messages.items()
        }
        with open(round_messages_path, "w") as f:
            json.dump(round_msgs_serializable, f, ensure_ascii=False)

        # write per-round test summaries if any
        try:
            test_summary_path = os.path.join(self.config["output_dir"], "memory", "test_summary.json")
            with open(test_summary_path, "w") as f:
                # use string keys for consistency
                serializable = {str(k): v for k, v in self.round_summaries.items()}
                json.dump(serializable, f, ensure_ascii=False)
        except Exception:
            # don't fail the callback on write error
            pass

    def _run_compile(self):
        if self.cur_round >= self.compile_round:
            return ''

        # checks = [self.check_forge, self.check_gas]
        # checks_parse = [self.parse_forge_stdout, self.parse_gas_stdout]
        # checks = [(self.check_forge, self.parse_forge_stdout)]
        # for check, parse_stdout in checks:
        #     output = check()
        #     query = parse_stdout(output) # query is a dict
        #     return query
        
        return run_forge_test(self.cur_t_sol)

    def get_compile_feedback(self):
        with open(self.cur_sol, 'r') as f:
            current_code = f.read()
        if "NoContent" in current_code:
            return None, None, None

        test_results = self._run_compile()
        slither_raw, vuln_count = self.get_slither_feedback(test_results)
        return test_results, slither_raw, vuln_count

    def get_slither_feedback(self, test_results):
        if test_results.get("compile_error"):
            print(f"[SKIP] Skipping slither due to compile error")
            slither_raw = None
            vuln_count = -1
        else:
            try:
                slither_raw = run_slither(self.cur_sol)
                _, vuln_count = get_slither_feedback_and_count(slither_raw)
            except Exception as e:
                print(f"[WARNING] Slither analysis failed: {e}")
                slither_raw = {"error": str(e)}
                vuln_count = -1

        return slither_raw, vuln_count

    def _record_round_summary(self, query, slither_raw=None, vuln_count=None):
        """Record test summary for current round including gas fees and slither results."""
        try:
            passed = query.get("passed", 0)
            failed = query.get("failed", 0)
            total = query.get("total", 0)
            
            summary = {
                "passed": passed,
                "failed": failed,
                "total": total,
                **({"fails": query.get("fails")} if isinstance(query, dict) and query.get("fails") else {})
            }
            
            # Add gas_fees if available in query
            if query.get("gas_fees"):
                summary["gas_fees"] = query["gas_fees"]
            
            # Add slither results if available
            if slither_raw is not None:
                summary["slither_raw"] = slither_raw
            if vuln_count is not None:
                summary["vuln_count"] = vuln_count
            
            self.round_summaries[self.cur_round] = summary
        except Exception:
            pass

    async def on_generate_response(self, runtime: Runtime, messages: List[Message]):
        if messages[-1].tool_calls or messages[-1].role == 'tool':  # noqa
            # subtask or tool-calling or tool response, skip
            return
        if (messages[-1].role == 'assistant' and not messages[-1].content): #
            self.feedback_ended = True
            self._feedback_ended_empty_assistant(runtime, messages)
            return
        
        self.round_messages[self.cur_round] = messages.copy()

        # Serialize checkpoint before appending feedback for recovery
        try:
            if self.checkpoint_path:
                state = {
                    # primitive counters and flags
                    "cur_round": self.cur_round,
                    "compile_round": self.compile_round,
                    "best_passed": self.best_passed,
                    "total_tests": self.total_tests,
                    "no_improve_rounds": self.no_improve_rounds,
                    "last_issue_length": self.last_issue_length,
                    "best_changed": self.best_changed,
                    "feedback_ended": self.feedback_ended,
                    "all_passed_vuln_round": self.all_passed_vuln_round,
                    "best_vuln_count": self.best_vuln_count,
                    "compile_error_count": self.compile_error_count,
                    "last_feedback": self.last_feedback,
                    # artifacts and messages
                    "best_code": self.best_code,
                    "origin_messages": [m.to_dict() for m in (self.origin_messages or [])],
                    "round_messages": {str(k): [m.to_dict() for m in v] for k, v in self.round_messages.items()},
                    "round_summaries": self.round_summaries,
                    # idempotency fields
                    "_compiled_rounds": list(self._compiled_rounds) if hasattr(self, '_compiled_rounds') else [],
                    "_last_issue_lengths": self._last_issue_lengths if hasattr(self, '_last_issue_lengths') else {},
                    "_round_feedbacks": self._round_feedbacks if hasattr(self, '_round_feedbacks') else {},
                }
                with open(self.checkpoint_path, "wb") as cf:
                    pickle.dump(state, cf)
        except Exception as e:
            print(f"[WARNING] Failed to write EvalCallback checkpoint: {e}")


        # Initialize idempotency tracking if not present
        if not hasattr(self, '_last_issue_lengths'):
            self._last_issue_lengths = {}
        if not hasattr(self, '_compiled_rounds'):
            self._compiled_rounds = set()
        if not hasattr(self, '_round_feedbacks'):
            self._round_feedbacks = {}
        
        # Restore last_feedback from previous round for retry scenarios
        if self.cur_round > 1 and (self.cur_round - 1) in self._round_feedbacks:
            self.last_feedback = self._round_feedbacks[self.cur_round - 1]

        # Idempotent tail length calculation
        # self.last_issue_length = len(messages) - 3 - self.last_issue_length
        total_tail = max(0, len(messages) - 3)
        last_issue_length = self._last_issue_lengths.get(self.cur_round - 1, 0)
        self.last_issue_length = max(0, total_tail - last_issue_length)
        # Store incremental length for this round
        self._last_issue_lengths[self.cur_round] = self.last_issue_length

        self.omit_intermediate_messages(messages)

        # Idempotent compile: only run once per round
        if self.cur_round not in self._compiled_rounds:
            query, slither_raw, vuln_count = self.get_compile_feedback() # query == test_result
            self._compiled_rounds.add(self.cur_round)
        else:
            # Retry detected: reuse previous results
            if self.cur_round in self.round_summaries:
                print(f"[EVAL] Round {self.cur_round} already compiled, reusing cached results")
                cached = self.round_summaries[self.cur_round]
                query = {
                    "passed": cached.get("passed", 0), 
                    "failed": cached.get("failed", 0),
                    "total": cached.get("total", 0),
                    "fails": cached.get("fails", {})
                }
                slither_raw = cached.get("slither_raw")
                vuln_count = cached.get("vuln_count")
            else:
                query, slither_raw, vuln_count = self.get_compile_feedback() # query == test_result
                self._compiled_rounds.add(self.cur_round)
        
        if slither_raw:
            slither_feedback, _ = get_slither_feedback_and_count(slither_raw)
        else:
            slither_feedback = None
        # Pass flags to control visibility in the prompt
        feedback, feedback_status = generate_feedback(
            query, 
            slither_feedback, 
            include_forge=self.enable_forge, 
            include_slither=self.enable_slither
        )
        
        
        from utils.feedback_utils import FeedbackStatus
        match feedback_status:
            case FeedbackStatus.NO_OUTPUT:
                self.feedback_ended = True
            case FeedbackStatus.COMPILE_ERROR:
                self.compile_error_count += 1
                print(f"[EVAL] round={self.cur_round} Compile failed. (error count: {self.compile_error_count})")
                
                # Check if compile errors exceed threshold
                if self.compile_error_count > 10:
                    print(f"[EVAL] Compile errors exceeded 10 times, stopping refinement.")
                    self.feedback_ended = True
                else:
                    # Check feedback similarity with last feedback
                    if self.last_feedback and feedback:
                        similarity = difflib.SequenceMatcher(None, feedback, self.last_feedback).ratio()
                        print(f"[EVAL] Feedback similarity: {similarity:.2f}")
                        if similarity > 0.9:
                            print(f"[EVAL] Feedback too similar (>0.9), stopping refinement.")
                            self.feedback_ended = True
                        else:
                            self.feedback_ended = False
                    else:
                        self.feedback_ended = False
                    self.last_feedback = feedback
                    self._round_feedbacks[self.cur_round] = feedback
                
                # used for token prune
                if self.best_passed == -1:  # still compile failed, use new generated code
                    self.best_changed = True
            
            case FeedbackStatus.NO_TESTS:
                self.feedback_ended = True
                print(f"[EVAL] round={self.cur_round} No tests detected.")
                self._record_round_summary(query, slither_raw, vuln_count)
            
            case FeedbackStatus.ALL_PASSED:
                passed = query.get("passed", 0)
                total = query.get("total", 0)
                print(f"[EVAL] round={self.cur_round} All tests passed: {passed}/{total}")
                self.best_passed = passed
                self.total_tests = total
                # best code
                with open(self.cur_sol, "r") as f:
                    self.best_code = f.read()
                self._record_round_summary(query, slither_raw, vuln_count)

                if self.enable_slither:
                    # Get baseline vuln_count from baseline_test table if available
                    baseline_entry = self.baseline_tracker.get_entry(self.file_path)
                    baseline_vuln_count = baseline_entry.get("vuln_count", -1) if baseline_entry else -1
                    
                    if self.all_passed_vuln_round == 0 and vuln_count >= 0:
                        self.best_vuln_count = vuln_count
                    self.all_passed_vuln_round += 1
                    if vuln_count == 0:
                        self.feedback_ended = True
                    else:
                        # Compare with baseline vuln_count
                        if baseline_vuln_count >= 0 and vuln_count <= baseline_vuln_count:
                            self.feedback_ended = True
                        elif vuln_count < self.best_vuln_count:
                            self.best_vuln_count = vuln_count
                            self.feedback_ended = True
                        else:
                            self.feedback_ended = False
                    if self.all_passed_vuln_round >= 2:
                        self.feedback_ended = True
                else:
                    self.feedback_ended = True
            
            case FeedbackStatus.SOME_FAILED:
                passed = query.get("passed", 0)
                failed = query.get("failed", 0)
                total = query.get("total", 0)
                print(f"[EVAL] round={self.cur_round} Tests: {passed}/{total} passed")
                self._record_round_summary(query, slither_raw, vuln_count)
                
                if passed > self.best_passed:
                    print(f"[EVAL] Improved: {self.best_passed} -> {passed}")
                    self.best_passed = passed
                    self.total_tests = total
                    # best code
                    with open(self.cur_sol, "r") as f:
                        self.best_code = f.read()
                    self.no_improve_rounds = 0
                    self.feedback_ended = False
                    self.best_changed = True
                else:
                    self.no_improve_rounds += 1
                    no_improves = 3 if self.best_passed == 0 else 2
                    if self.no_improve_rounds >= no_improves:
                        print(f"[EVAL] No improvement in {self.no_improve_rounds} rounds. Stopping.")
                        self.feedback_ended = True
                        feedback = f'No progress after {self.no_improve_rounds} refine rounds, stopping refinement.\n{feedback}'
                    else:
                        self.feedback_ended = False

        messages.append(Message(role='user', content=feedback))
        self._feedback_ended(runtime, messages)
                
    def _feedback_ended(self, runtime: Runtime, messages: List[Message]):
        if self.feedback_ended: # added for quickly stopping refinement, but failed to dive into after_tool_call
            runtime.should_stop = True
            if runtime.should_stop: # and self.best_passed >= 0: # True: write the best code.
                # delegate to helper so other hooks can reuse this behavior
                try:
                    self.round_messages[self.cur_round] = messages.copy()
                    self.origin_messages.append(messages[-1])
                    self._write_best_and_memory()
                    # On successful write, delete checkpoint file
                    try:
                        if self.checkpoint_path and os.path.exists(self.checkpoint_path):
                            os.remove(self.checkpoint_path)
                    except Exception:
                        pass
                except Exception as e:
                    # keep callback robust; log and continue
                    print(f"[EVAL] failed to write best code or memory: {e}")
                    raise e
    def _feedback_ended_empty_assistant(self, runtime: Runtime, messages: List[Message]):
        runtime.should_stop = True
        if runtime.should_stop: # and self.best_passed >= 0: # True: write the best code.
            # delegate to helper so other hooks can reuse this behavior
            try:
                self._write_best_and_memory()
                # On successful write, delete checkpoint file
                try:
                    if self.checkpoint_path and os.path.exists(self.checkpoint_path):
                        os.remove(self.checkpoint_path)
                except Exception:
                    pass
            except Exception as e:
                # keep callback robust; log and continue
                print(f"[EVAL] failed to write best code or memory: {e}")
                raise e


    async def on_tool_call(self, runtime: Runtime, messages: List[Message]):
        # todo: extract code blocks and write to file (in artifact callback)
        # design, _ = extract_code_blocks(messages[-1].content, target_filename='design.txt')
        # if len(design) > 0:
        #     front, design = messages[-1].content.split('```text: design.txt', maxsplit=1)
        #     design, end = design.rsplit('```', 1)
        #     design = design.strip()
        #     if design:
        #         messages[2].content = await self.do_arch_update(runtime=runtime, messages=messages, updated_arch=design)
        pass

    async def after_tool_call(self, runtime: Runtime, messages: List[Message]):
        if messages[-1].tool_calls or messages[-1].role == 'tool':
            return
        
        runtime.should_stop = runtime.should_stop and self.feedback_ended
        
        # Increment round only after successful tool call (LLM generation success)
        self.cur_round += 1

        print(f"[EVAL] after_tool_call: should_stop={runtime.should_stop}, best_passed={self.best_passed}")
        


if __name__ == '__main__':
    s = """...
Ran 13 tests for test/utils/SlotDerivation.t.sol:SlotDerivationTest
[PASS] testDeriveArray(uint256,uint256) (runs: 5001, μ: 30348, ~: 30013)
...
Ran 1 test suite in 413.23ms (411.68ms CPU time): 55 tests passed, 1 failed, 0 skipped (56 total tests)

Failing tests:
Encountered 1 failing test in test/utils/Packing.t.sol:PackingTest
[FAIL: assertion failed: 0x1200000000000000000000000000000000000000000000000000000000000000 != 0x0000000000000000000000000000000000000000000000000000000000000000; counterexample: calldata=0x345f34f312000000000000000000000000000000000000000000000000000000000000009800000000000000000000000000000000000000000000000000000000000000 args=[0x12, 0x98]] testPack(bytes1,bytes1) (runs: 0, μ: 0, ~: 0)                                                                                                              

Encountered a total of 1 failing tests, 55 tests succeeded
"""

    # e = EvalCallback({})
    # a = e.parse_forge_stdout(s)
    # print(a)

    # Extract passed, failed, total using regex
    # pattern = r":\s*(\d+)\s*tests\s*passed,\s*(\d+)\s*failed.*?\((\d+)\s*total\s*tests\)"
    # match = re.search(pattern, s)
    #
    # if match:
    #     passed = int(match.group(1))
    #     failed = int(match.group(2))
    #     total = int(match.group(3))
    #     print(f"passed={passed}, failed={failed}, total={total}")
    # else:
    #     print("No match found.")
