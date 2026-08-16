"""
Forge testing utilities for running and parsing forge test results.
Extracted from eval_callback.py for reuse in baseline scripts.
"""
import os
import re
import subprocess
from typing import Dict, Any, Optional

from dotenv import load_dotenv
load_dotenv()

def _env_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    if not value:
        return default
    try:
        parsed = int(value)
        return parsed if parsed > 0 else default
    except ValueError:
        return default

def _find_foundry_root(start_dir: str) -> str:
    current = os.path.abspath(start_dir)
    while True:
        if os.path.exists(os.path.join(current, "foundry.toml")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return os.path.abspath(start_dir)
        current = parent

def check_forge(
    test_file_path: str,
    is_gas_report: bool = False,
    fuzz_seed: Optional[str] = None,
) -> str:
    """
    Run forge test for a specific test file.
    
    Args:
        test_file_path: Absolute path to the test file (e.g., /path/to/test.t.sol)
        
    Returns:
        stdout from forge test command
        
    Raises:
        RuntimeError: If FORGE_PATH environment variable is not set
    """
    test_file_path = os.path.abspath(test_file_path)
    work_dir = _find_foundry_root(os.path.dirname(test_file_path))
    match_path = os.path.relpath(test_file_path, work_dir)
    
    # Extract test profile from path if it contains test-profiles
    # e.g., test-profiles/openzeppelin-contracts-v4/test/... -> openzeppelin-contracts-v4
    test_profile = None
    if 'test-profiles/' in test_file_path:
        path_parts = test_file_path.split('/')
        for i, part in enumerate(path_parts):
            if part == 'test-profiles' and i + 1 < len(path_parts):
                test_profile = path_parts[i + 1]
                break
    
    # Read forge binary path from environment variable FORGE_PATH (no default)
    try:
        forge_bin = os.environ['FORGE_PATH']
    except KeyError:
        raise RuntimeError(
            "Environment variable FORGE_PATH is not set. "
            "Please set it (e.g. in .env) before running."
        )
    
    # Prepare environment with FOUNDRY_PROFILE if test profile is found
    env = os.environ.copy()
    if test_profile:
        env['FOUNDRY_PROFILE'] = test_profile
    # Special case: solady ext/ithaca tests need ithaca profile (for Ithaca precompiles)
    elif 'solady' in test_file_path and '/ext/ithaca/' in test_file_path:
        env['FOUNDRY_PROFILE'] = 'ithaca'
    # Special case: files with "Transient" in name need post_cancun profile (for EIP-1153 transient storage)
    # This is specifically for solady project which skips Transient tests in default profile
    elif 'solady' in test_file_path and 'Transient' in match_path:
        env['FOUNDRY_PROFILE'] = 'post_cancun'
    
    # Try running forge test with timeout retry. Gas reports on heavy fuzz tests
    # can be much slower than normal test execution, so keep a separate limit.
    max_retries = _env_int("FORGE_MAX_RETRIES", 2)
    build_timeout = _env_int("FORGE_BUILD_TIMEOUT", 120)
    test_timeout = _env_int("FORGE_GAS_REPORT_TIMEOUT" if is_gas_report else "FORGE_TEST_TIMEOUT", 7200 if is_gas_report else 150)
    for attempt in range(max_retries):
        try:
            subprocess.run(
                [forge_bin, 'build'], capture_output=True,
                cwd=work_dir,
                timeout=build_timeout,
                env=env
            )
            # Build test command with optional --gas-report flag
            test_cmd = [forge_bin, 'test', '--match-path', f'{match_path}']
            if fuzz_seed:
                test_cmd.extend(['--fuzz-seed', fuzz_seed])
            if is_gas_report:
                test_cmd.append('--gas-report')
            
            test_process = subprocess.run(
                test_cmd,
                capture_output=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=work_dir,
                timeout=test_timeout,
                env=env
            )
            captured_stdout = test_process.stdout.decode()# + test_process.stderr.decode()
            return captured_stdout
        except subprocess.TimeoutExpired:
            if attempt < max_retries - 1:
                print(f"[WARNING] Forge test timeout, retrying... (attempt {attempt + 1}/{max_retries})")
            else:
                print(f"[ERROR] Forge test timeout after {max_retries} attempts")
                raise  # Re-raise to be caught by caller


def filter_compile_errors(compiler_output: str) -> str:
    """
    Filter out warnings from compiler output, keeping only errors.
    
    Args:
        compiler_output: Full compiler output with warnings and errors
        
    Returns:
        Filtered output containing only error messages
    """
    lines = compiler_output.split('\n')
    filtered_lines = []
    skip_until_next_section = False
    start = False
    
    for i, line in enumerate(lines):
        # Keep the "Compiler run failed" header
        if "Compiler run failed" in line:
            filtered_lines.append(line)
            start = True
            continue
        if not start:
            continue
        
        # Check if this is a warning line
        if line.startswith('Warning ('):
            skip_until_next_section = True
            continue
        
        # Check if this is an error line
        if line.startswith('Error ('):
            skip_until_next_section = False
            filtered_lines.append(line)
            continue
        
        # If we're in a warning section, skip
        if skip_until_next_section:
            # Check if we've reached the next warning or error
            if i + 1 < len(lines) and (lines[i + 1].startswith('Warning (') or lines[i + 1].startswith('Error (')):
                skip_until_next_section = False
            continue
        
        # Keep non-warning/error lines (context, file paths, etc.)
        if not skip_until_next_section:
            filtered_lines.append(line)
    
    return '\n'.join(filtered_lines)


def parse_forge_stdout(captured_stdout: str) -> Dict[str, Any]:
    """
    Parse forge test stdout to extract test results.
    
    Args:
        captured_stdout: stdout string from forge test command
        
    Returns:
        Dictionary with test results:
        - If compile error: {"compile_error": error_message}
        - If tests run: {"passed": int, "failed": int, "total": int, "fails": dict}
          where "fails" is a dict mapping test names to failure messages
    """
    # Check if compiler output contains "Compiler run failed:", if error return error message directly
    if "Compiler run failed" in captured_stdout:
        # Filter out warnings, keep only errors
        filtered_error = filter_compile_errors(captured_stdout)
        return {"compile_error": filtered_error}
    
    # Extract passed, failed, total using regex
    pattern_d = r":\s*(\d+)\s*tests\s*passed,\s*(\d+)\s*failed.*?\((\d+)\s*total\s*tests\)"
    match_d = re.search(pattern_d, captured_stdout)
    summary = None
    if match_d:
        passed = int(match_d.group(1))
        failed = int(match_d.group(2))
        total = int(match_d.group(3))
        summary = {"passed": passed, "failed": failed, "total": total}
    else:
        # If no summary, still try to extract failing-tests section
        passed = failed = total = None
    
    # Extract part after "Failing tests:"
    fails_dict = {}
    parts = re.split(r"Failing tests:\s*", captured_stdout, maxsplit=1)
    if len(parts) >= 2:
        section = parts[1]
        
        # Match complete [FAIL: ...] line, capture test name and full line content (remove runs and gas parts)
        pattern = re.compile(
            r"^\[FAIL:[^\n]*?\]\s+([a-zA-Z0-9_]+\(.*?\))\s*(?:\(runs:.*)?(?:\s*\(gas:\s*\d+\))?$", re.MULTILINE
        )
        
        for match in pattern.finditer(section):
            full_line = match.group(0)
            test_name = match.group(1)
            # Remove trailing runs and gas information
            cleaned_line = re.sub(r"\(runs:.*", "", full_line).strip()
            cleaned_line = re.sub(r"\(gas:\s*\d+\).*", "", cleaned_line).strip()
            fails_dict[test_name] = cleaned_line
    
    # Organize return value: prioritize returning summary + fails (if summary exists)
    if summary is not None:
        summary["fails"] = fails_dict
        return summary
    
    # If no summary but has fails (or no useful information parsed), return original output as error message or return failure details
    if fails_dict:
        return {"passed": 0, "failed": len(fails_dict), "total": None, "fails": fails_dict}
    
    # Fallback: return original output as compile_error (or unparsed information)
    return {"compile_error": captured_stdout}


def run_forge_test(test_file_path: str) -> Dict[str, Any]:
    """
    Run forge test and parse both test results and gas fees in one call.
    
    Args:
        test_file_path: Absolute path to the test file
        
    Returns:
        Dictionary with parsed test results and gas fees:
        - If compile error: {"compile_error": error_message, "gas_fees": {}}
        - If tests run: {"passed": int, "failed": int, "total": int, "fails": dict, "gas_fees": dict}
          where "fails" maps test names to failure messages
          and "gas_fees" maps test method signatures to gas fees
    """
    stdout = check_forge(test_file_path)
    results = parse_forge_stdout(stdout)
    # gas_report = check_forge(test_file_path, is_gas_report=True)
    # gas_fees = extract_gas_fees_from_stdout(gas_report)
    
    # Add gas_fees to results
    results["gas_fees"] = run_gas_report(test_file_path)
    
    return results

def run_gas_report(test_file_path: str):
    gas_report = check_forge(test_file_path, is_gas_report=True)
    gas_fees = extract_gas_fees_from_stdout(gas_report)
    return gas_fees

def extract_gas_fees_from_stdout(captured_stdout: str) -> Dict[str, int]:
    """
    Extract gas fee information from forge test output.
    
    Args:
        captured_stdout: stdout string from forge test command
        
    Returns:
        Dictionary mapping test method signatures to gas fees
        Format for fuzz tests: {"methodSignature(args)": {"-": mean_gas, "~": median_gas}}
        Format for normal tests: {"methodSignature(args)": {"gas": gas_value}}
    
    Note:
        Fuzz test output: [PASS] testMethod() (runs: 256, μ: 12345, ~: 12000)
        Normal test output: [PASS] testMethod() (gas: 12345)
    """
    gas_fees = {}
    
    # Helper function to extract method signature with balanced parentheses
    def extract_signature(line: str) -> str:
        # Find the test method name start
        match = re.search(r'\[(?:PASS)[^\]]*\]\s+([a-zA-Z0-9_]+)\(', line)
        if not match:
            return None
        
        method_name = match.group(1)
        start_pos = match.end() - 1  # Position of the opening parenthesis
        
        # Balance parentheses to find the complete signature
        paren_count = 0
        end_pos = start_pos
        for i in range(start_pos, len(line)):
            if line[i] == '(':
                paren_count += 1
            elif line[i] == ')':
                paren_count -= 1
                if paren_count == 0:
                    end_pos = i + 1
                    break
        
        return line[match.start(1):end_pos]
    
    # Pattern for fuzz tests with mean and median
    # Example: [PASS] testPack(bytes1,bytes1) (runs: 256, μ: 30348, ~: 30013)
    fuzz_pattern = re.compile(
        r"\[(?:PASS)[^\]]*\]\s+[a-zA-Z0-9_]+\([^\n]*?\)\s*\(runs:\s*\d+,\s*μ:\s*(\d+),\s*~:\s*(\d+)\)"
    )
    
    # Pattern for normal tests with single gas value
    # Example: [PASS] testBeacon() (gas: 1331166)
    normal_pattern = re.compile(
        r"\[(?:PASS)[^\]]*\]\s+[a-zA-Z0-9_]+\([^\n]*?\)\s*\(gas:\s*(\d+)\)"
    )
    
    # Process each line to extract signatures and gas values
    for line in captured_stdout.split('\n'):
        # Try fuzz pattern first
        fuzz_match = fuzz_pattern.search(line)
        if fuzz_match:
            signature = extract_signature(line)
            if signature:
                mean_gas = int(fuzz_match.group(1))
                median_gas = int(fuzz_match.group(2))
                gas_fees[signature] = {"-": mean_gas, "~": median_gas}
            continue
        
        # Try normal pattern
        normal_match = normal_pattern.search(line)
        if normal_match:
            signature = extract_signature(line)
            if signature and signature not in gas_fees:  # Don't overwrite fuzz results
                gas_value = int(normal_match.group(1))
                gas_fees[signature] = {"gas": gas_value}
    
    return gas_fees



# For testing
if __name__ == '__main__':
    # Example test output
    test_output = """
Ran 13 tests for test/utils/SlotDerivation.t.sol:SlotDerivationTest
[PASS] testDeriveArray(uint256,uint256) (runs: 5001, μ: 30348, ~: 30013)

Ran 1 test suite in 413.23ms (411.68ms CPU time): 55 tests passed, 1 failed, 0 skipped (56 total tests)

Failing tests:
Encountered 1 failing test in test/utils/Packing.t.sol:PackingTest
[FAIL: assertion failed] testPack(bytes1,bytes1) (runs: 0, μ: 0, ~: 0)
[FAIL: DeploymentFailed()] testChangeAdmin() (gas: 96901679)

Encountered a total of 1 failing tests, 55 tests succeeded
"""
    expected = {'passed': 55, 'failed': 1, 'total': 56, 'fails': {'testPack(bytes1,bytes1)': '[FAIL: assertion failed] testPack(bytes1,bytes1)', 'testChangeAdmin()': '[FAIL: DeploymentFailed()] testChangeAdmin()'}}
    result = parse_forge_stdout(test_output)
    assert result == expected, "parse_forge_stdout did not produce expected result"
    # print("Parse result:", result)
    
    expected = {'testDeriveArray(uint256,uint256)': {'-': 30348, '~': 30013}}
    gas_fees = extract_gas_fees_from_stdout(test_output)
    assert gas_fees == expected, "extract_gas_fees_from_stdout did not produce expected gas fees"
    # print("Gas fees:", gas_fees)
    
    # Test filter_compile_errors
    print("\n" + "="*80)
    print("Testing filter_compile_errors")
    print("="*80)
    
    compiler_output_with_warnings = """Compiler run failed:
Warning (5159): "selfdestruct" has been deprecated. Note that, starting from the Cancun hard fork, the underlying opcode no longer deletes the code and data associated with an account and only transfers its Ether to the beneficiary, unless executed in the same transaction in which the contract was created (see EIP-6780). Any use in newly deployed contracts is strongly discouraged even if the new behavior is taken into account. Future changes to the EVM might further reduce the functionality of the opcode.
  --> src/attacks/ForceAttack.sol:10:9:
   |
10 |         selfdestruct(target);
   |         ^^^^^^^^^^^^

Warning (2462): Visibility for constructor is ignored. If you want the contract to be non-deployable, making it "abstract" is sufficient.
  --> src/attacks/ReentranceAttack.sol:16:5:
   |
16 |     constructor(address payable _target) public payable {
   |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (9302): Return value of low-level calls not used.
  --> src/levels/Denial.sol:19:9:
   |
19 |         partner.call{value: amountToSend}("");
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Error (7920): Identifier not found or not unique.
src/levels/MotorbikeFactory.sol:15:9: DeclarationError: Identifier not found or not unique.
        Engine engine = new Engine();
        ^----^
"""
    expected = """Compiler run failed:
Error (7920): Identifier not found or not unique.
src/levels/MotorbikeFactory.sol:15:9: DeclarationError: Identifier not found or not unique.
        Engine engine = new Engine();
        ^----^
"""
    filtered_output = filter_compile_errors(compiler_output_with_warnings)
    assert filtered_output.strip() == expected.strip(), "filter_compile_errors did not produce expected output"

    gas_report = """[⠊] Compiling...
No files changed, compilation skipped
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)

Ran 13 tests for test/LibTransient.t.sol:LibTransientTest
[PASS] testSetAndGetAddressTransient(uint256,address) (runs: 331, μ: 32609, ~: 34796)
[PASS] testSetAndGetBoolTransient(uint256,bool) (runs: 331, μ: 30669, ~: 28953)
[PASS] testSetAndGetBytes32Transient(uint256,bytes32) (runs: 331, μ: 32484, ~: 34380)
[PASS] testSetAndGetBytesTransient() (gas: 51293)
[PASS] testSetAndGetBytesTransient(uint256,bytes) (runs: 331, μ: 202999, ~: 54577)
[PASS] testSetAndGetBytesTransientCalldata(uint256,bytes) (runs: 331, μ: 49651, ~: 53711)
[FAIL: assertion failed: 0x0000000000000000000000000000000000000000000000000000000000000020 != 0x0000000000000000000000000000000000000000000000000000000000001dec; counterexample: calldata=0xe9e37a820000000000000000000000000000000000000000000000000000000000001974000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000001dec000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000029fa args=[6516, 0x0000000000000000000000000000000000000000000000000000000000001dec, 0x00000000000000000000000000000000000000000000000000000000000029fa]] testSetAndGetBytesTransientCalldata(uint256,bytes,bytes) (runs: 2, μ: 95006, ~: 95006)
[PASS] testSetAndGetInt256Transient(uint256,int256) (runs: 331, μ: 32396, ~: 34418)
[PASS] testSetAndGetUint256Transient(uint256,uint256) (runs: 331, μ: 32340, ~: 34402)
[FAIL: next call did not revert as expected; counterexample: calldata=0x218cb965ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff args=[115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]]] testSetBytesTransientRevertsIfLengthTooBig(uint256) (runs: 4, μ: 26391, ~: 26429)
[PASS] testSetBytesTransientRevertsIfLengthTooBigCalldata(uint256) (runs: 331, μ: 26330, ~: 26266)
[FAIL: assertion failed: 1 != 11] testUint256IncDecTransient() (gas: 445533)
[PASS] test__codesize() (gas: 11379)
Suite result: FAILED. 10 passed; 3 failed; 0 skipped; finished in 14.21s (14.41s CPU time)

╭---------------------------------------------------+-----------------+-------+--------+-------+---------╮
| test/LibTransient.t.sol:LibTransientTest Contract |                 |       |        |       |         |
+========================================================================================================+
| Deployment Cost                                   | Deployment Size |       |        |       |         |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| 2229474                                           | 11065           |       |        |       |         |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                   |                 |       |        |       |         |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                     | Min             | Avg   | Median | Max   | # Calls |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| setBytesTransientWithLengthTooBig                 | 0               | 9293  | 0      | 46466 | 5       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| setBytesTransientWithLengthTooBigCalldata         | 0               | 0     | 0      | 0     | 256     |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintDecCompat(uint256)                           | 23795           | 25338 | 25338  | 26882 | 2       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintDecCompat(uint256,uint256)                   | 22276           | 24444 | 23981  | 27076 | 3       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintDecSignedCompat                              | 26971           | 27157 | 27157  | 27343 | 2       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintIncCompat(uint256)                           | 22002           | 24888 | 25335  | 26879 | 4       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintIncCompat(uint256,uint256)                   | 24025           | 25572 | 25572  | 27120 | 2       |
|---------------------------------------------------+-----------------+-------+--------+-------+---------|
| tUintIncSignedCompat                              | 26948           | 27134 | 27134  | 27320 | 2       |
╰---------------------------------------------------+-----------------+-------+--------+-------+---------╯


Ran 1 test suite in 14.27s (14.21s CPU time): 10 tests passed, 3 failed, 0 skipped (13 total tests)

Failing tests:
Encountered 3 failing tests in test/LibTransient.t.sol:LibTransientTest
[FAIL: assertion failed: 0x0000000000000000000000000000000000000000000000000000000000000020 != 0x0000000000000000000000000000000000000000000000000000000000001dec; counterexample: calldata=0xe9e37a820000000000000000000000000000000000000000000000000000000000001974000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000001dec000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000029fa args=[6516, 0x0000000000000000000000000000000000000000000000000000000000001dec, 0x00000000000000000000000000000000000000000000000000000000000029fa]] testSetAndGetBytesTransientCalldata(uint256,bytes,bytes) (runs: 2, μ: 95006, ~: 95006)
[FAIL: next call did not revert as expected; counterexample: calldata=0x218cb965ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff args=[115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]]] testSetBytesTransientRevertsIfLengthTooBig(uint256) (runs: 4, μ: 26391, ~: 26429)
[FAIL: assertion failed: 1 != 11] testUint256IncDecTransient() (gas: 445533)

Encountered a total of 3 failing tests, 10 tests succeeded
"""
    expected = {'passed': 10, 'failed': 3, 'total': 13, 'fails': {'testSetAndGetBytesTransientCalldata(uint256,bytes,bytes)': '[FAIL: assertion failed: 0x0000000000000000000000000000000000000000000000000000000000000020 != 0x0000000000000000000000000000000000000000000000000000000000001dec; counterexample: calldata=0xe9e37a820000000000000000000000000000000000000000000000000000000000001974000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000001dec000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000029fa args=[6516, 0x0000000000000000000000000000000000000000000000000000000000001dec, 0x00000000000000000000000000000000000000000000000000000000000029fa]] testSetAndGetBytesTransientCalldata(uint256,bytes,bytes)', 'testSetBytesTransientRevertsIfLengthTooBig(uint256)': '[FAIL: next call did not revert as expected; counterexample: calldata=0x218cb965ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff args=[115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]]] testSetBytesTransientRevertsIfLengthTooBig(uint256)', 'testUint256IncDecTransient()': '[FAIL: assertion failed: 1 != 11] testUint256IncDecTransient()'}}
    result = parse_forge_stdout(gas_report)
    assert result == expected, "parse_forge_stdout did not produce expected result for gas_report"
    # print("Parse result:", result)
    expected = {'testSetAndGetAddressTransient(uint256,address)': {'-': 32609, '~': 34796}, 'testSetAndGetBoolTransient(uint256,bool)': {'-': 30669, '~': 28953}, 'testSetAndGetBytes32Transient(uint256,bytes32)': {'-': 32484, '~': 34380}, 'testSetAndGetBytesTransient()': {'gas': 51293}, 'testSetAndGetBytesTransient(uint256,bytes)': {'-': 202999, '~': 54577}, 'testSetAndGetBytesTransientCalldata(uint256,bytes)': {'-': 49651, '~': 53711}, 'testSetAndGetInt256Transient(uint256,int256)': {'-': 32396, '~': 34418}, 'testSetAndGetUint256Transient(uint256,uint256)': {'-': 32340, '~': 34402}, 'testSetBytesTransientRevertsIfLengthTooBigCalldata(uint256)': {'-': 26330, '~': 26266}, 'test__codesize()': {'gas': 11379}}
    gas_fees = extract_gas_fees_from_stdout(gas_report)
    assert gas_fees == expected, "extract_gas_fees_from_stdout did not produce expected gas fees for gas_report"
    # print(f"Gas fees from gas report: {gas_fees}. Total entries: {len(gas_fees)}")

    gas_report = """No files changed, compilation skipped

Ran 42 tests for test/DateTimeLib.t.sol:DateTimeLibTest
[PASS] testAddSubDiffDays(uint256,uint256) (runs: 331, μ: 4217, ~: 4209)
[PASS] testAddSubDiffHours(uint256,uint256) (runs: 331, μ: 4168, ~: 4155)
[PASS] testAddSubDiffMinutes(uint256,uint256) (runs: 331, μ: 4149, ~: 4129)
[PASS] testAddSubDiffMonths(uint256,uint256) (runs: 331, μ: 7269, ~: 7257)
[PASS] testAddSubDiffSeconds(uint256,uint256) (runs: 331, μ: 3763, ~: 3721)
[PASS] testAddSubDiffYears(uint256,uint256) (runs: 331, μ: 6811, ~: 6822)
[PASS] testDateTimeArithmeticReverts() (gas: 4495)
[PASS] testDateTimeMaxSupported() (gas: 2823)
[PASS] testDateTimeToAndFroTimestamp((uint256,uint256,uint256,uint256,uint256,uint256)) (runs: 331, μ: 4145, ~: 4129)
[PASS] testDateToAndFroEpochDay((uint256,uint256,uint256,uint256,uint256,uint256)) (runs: 331, μ: 2565, ~: 2588)
[PASS] testDateToAndFroEpochDay() (gas: 877945)
[PASS] testDateToAndFroTimestamp() (gas: 926776)
[PASS] testDateToEpochDay() (gas: 1559)
[PASS] testDateToEpochDayDifferential((uint256,uint256,uint256,uint256,uint256,uint256)) (runs: 331, μ: 2311, ~: 2346)
[PASS] testDateToEpochDayDifferential2((uint256,uint256,uint256,uint256,uint256,uint256)) (runs: 331, μ: 2225, ~: 2249)
[PASS] testDateToEpochDayGas() (gas: 764427)
[PASS] testDateToEpochDayGas2() (gas: 770404)
[PASS] testDayOfWeek() (gas: 175255)
[PASS] testDaysInMonth() (gas: 1226)
[PASS] testDaysInMonth(uint256,uint256) (runs: 331, μ: 1072, ~: 1084)
[PASS] testDaysToDate() (gas: 8377)
[PASS] testEpochDayToDate(uint256) (runs: 331, μ: 1045, ~: 1045)
[PASS] testEpochDayToDateDifferential(uint256) (runs: 331, μ: 1780, ~: 1721)
[PASS] testEpochDayToDateDifferential2(uint256) (runs: 331, μ: 1791, ~: 1709)
[PASS] testEpochDayToDateGas() (gas: 348457)
[PASS] testEpochDayToDateGas2() (gas: 360513)
[PASS] testIsLeapYear() (gas: 741)
[PASS] testIsLeapYear(uint256) (runs: 331, μ: 538, ~: 517)
[PASS] testIsSupportedDateFalse() (gas: 1180)
[PASS] testIsSupportedDateTime((uint256,uint256,uint256,uint256,uint256,uint256)) (runs: 331, μ: 2942, ~: 2949)
[PASS] testIsSupportedDateTrue() (gas: 626)
[PASS] testIsSupportedEpochDayFalse() (gas: 494)
[PASS] testIsSupportedEpochDayTrue() (gas: 305)
[PASS] testIsSupportedTimestampFalse() (gas: 541)
[PASS] testIsSupportedTimestampTrue() (gas: 326)
[PASS] testIsWeekEnd(uint256) (runs: 331, μ: 697, ~: 617)
[PASS] testMondayTimestamp() (gas: 1106)
[PASS] testMondayTimestamp(uint256) (runs: 331, μ: 758, ~: 836)
[PASS] testNthWeekdayInMonthOfYearTimestamp() (gas: 12053)
[PASS] testNthWeekdayInMonthOfYearTimestamp(uint256,uint256,uint256,uint256) (runs: 331, μ: 3514, ~: 3550)
[PASS] testWeekday() (gas: 682)
[PASS] test__codesize() (gas: 19163)
Suite result: ok. 42 passed; 0 failed; 0 skipped; finished in 34.02ms (220.08ms CPU time)


Ran 1 test suite in 204.46ms (34.02ms CPU time): 42 tests passed, 0 failed, 0 skipped (42 total tests)
"""
    print()
    expected = {'passed': 42, 'failed': 0, 'total': 42, 'fails': {}}
    result = parse_forge_stdout(gas_report)
    assert result == expected, "parse_forge_stdout did not produce expected result for gas_report 2"
    # print("Parse result:", result)
    expected = {'testAddSubDiffDays(uint256,uint256)': {'-': 4217, '~': 4209}, 'testAddSubDiffHours(uint256,uint256)': {'-': 4168, '~': 4155}, 'testAddSubDiffMinutes(uint256,uint256)': {'-': 4149, '~': 4129}, 'testAddSubDiffMonths(uint256,uint256)': {'-': 7269, '~': 7257}, 'testAddSubDiffSeconds(uint256,uint256)': {'-': 3763, '~': 3721}, 'testAddSubDiffYears(uint256,uint256)': {'-': 6811, '~': 6822}, 'testDateTimeArithmeticReverts()': {'gas': 4495}, 'testDateTimeMaxSupported()': {'gas': 2823}, 'testDateTimeToAndFroTimestamp((uint256,uint256,uint256,uint256,uint256,uint256))': {'-': 4145, '~': 4129}, 'testDateToAndFroEpochDay((uint256,uint256,uint256,uint256,uint256,uint256))': {'-': 2565, '~': 2588}, 'testDateToAndFroEpochDay()': {'gas': 877945}, 'testDateToAndFroTimestamp()': {'gas': 926776}, 'testDateToEpochDay()': {'gas': 1559}, 'testDateToEpochDayDifferential((uint256,uint256,uint256,uint256,uint256,uint256))': {'-': 2311, '~': 2346}, 'testDateToEpochDayDifferential2((uint256,uint256,uint256,uint256,uint256,uint256))': {'-': 2225, '~': 2249}, 'testDateToEpochDayGas()': {'gas': 764427}, 'testDateToEpochDayGas2()': {'gas': 770404}, 'testDayOfWeek()': {'gas': 175255}, 'testDaysInMonth()': {'gas': 1226}, 'testDaysInMonth(uint256,uint256)': {'-': 1072, '~': 1084}, 'testDaysToDate()': {'gas': 8377}, 'testEpochDayToDate(uint256)': {'-': 1045, '~': 1045}, 'testEpochDayToDateDifferential(uint256)': {'-': 1780, '~': 1721}, 'testEpochDayToDateDifferential2(uint256)': {'-': 1791, '~': 1709}, 'testEpochDayToDateGas()': {'gas': 348457}, 'testEpochDayToDateGas2()': {'gas': 360513}, 'testIsLeapYear()': {'gas': 741}, 'testIsLeapYear(uint256)': {'-': 538, '~': 517}, 'testIsSupportedDateFalse()': {'gas': 1180}, 'testIsSupportedDateTime((uint256,uint256,uint256,uint256,uint256,uint256))': {'-': 2942, '~': 2949}, 'testIsSupportedDateTrue()': {'gas': 626}, 'testIsSupportedEpochDayFalse()': {'gas': 494}, 'testIsSupportedEpochDayTrue()': {'gas': 305}, 'testIsSupportedTimestampFalse()': {'gas': 541}, 'testIsSupportedTimestampTrue()': {'gas': 326}, 'testIsWeekEnd(uint256)': {'-': 697, '~': 617}, 'testMondayTimestamp()': {'gas': 1106}, 'testMondayTimestamp(uint256)': {'-': 758, '~': 836}, 'testNthWeekdayInMonthOfYearTimestamp()': {'gas': 12053}, 'testNthWeekdayInMonthOfYearTimestamp(uint256,uint256,uint256,uint256)': {'-': 3514, '~': 3550}, 'testWeekday()': {'gas': 682}, 'test__codesize()': {'gas': 19163}}
    gas_fees = extract_gas_fees_from_stdout(gas_report)
    assert gas_fees == expected, "extract_gas_fees_from_stdout did not produce expected gas fees for gas_report 2"
    print(f"Gas fees from gas report 2: {gas_fees}. Total entries: {len(gas_fees)}")
    # Sort and print gas_fees keys
    # for key in sorted(gas_fees.keys()):
    #     print(f"{key}: {gas_fees[key]}")

    gas_report3 = """No files changed, compilation skipped

Warning: `testFail*` has been deprecated and will be removed in the next release. Consider changing to test_Revert[If|When]_Condition and expecting a revert. Found deprecated testFail* function(s): testFail_redeem, testFail_withdraw.
Ran 27 tests for test/token/ERC20/extensions/ERC4626.t.sol:ERC4626StdTest
[PASS] testFail_redeem((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1200331, ~: 1202793)
[PASS] testFail_withdraw((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1205594, ~: 1207648)
[PASS] testFuzzDecimalsOverflow(uint8) (runs: 5001, μ: 1133386, ~: 1133551)
[PASS] test_RT_deposit_redeem((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1267473, ~: 1268419)
[PASS] test_RT_deposit_withdraw((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1270410, ~: 1270376)
[PASS] test_RT_mint_redeem((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1268525, ~: 1268512)
[PASS] test_RT_mint_withdraw((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1271149, ~: 1270487)
[PASS] test_RT_redeem_deposit((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1269067, ~: 1268512)
[PASS] test_RT_redeem_mint((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1268986, ~: 1268437)
[PASS] test_RT_withdraw_deposit((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1270570, ~: 1270446)
[PASS] test_RT_withdraw_mint((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1271388, ~: 1270449)
[PASS] test_asset((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1070723, ~: 1071025)
[PASS] test_convertToAssets((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1133144, ~: 1133108)
[PASS] test_convertToShares((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1133298, ~: 1133198)
[PASS] test_deposit((address[4],uint256[4],uint256[4],int256),uint256,uint256) (runs: 5000, μ: 1223921, ~: 1224424)
[PASS] test_maxDeposit((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1070960, ~: 1071094)
[PASS] test_maxMint((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1070582, ~: 1071067)
[PASS] test_maxRedeem((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1071048, ~: 1071286)
[PASS] test_maxWithdraw((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1072871, ~: 1073200)
[PASS] test_mint((address[4],uint256[4],uint256[4],int256),uint256,uint256) (runs: 5000, μ: 1224324, ~: 1224598)
[PASS] test_previewDeposit((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1242733, ~: 1242937)
[PASS] test_previewMint((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1243402, ~: 1243105)
[PASS] test_previewRedeem((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1244488, ~: 1243677)
[PASS] test_previewWithdraw((address[4],uint256[4],uint256[4],int256),uint256) (runs: 5001, μ: 1246289, ~: 1245648)
[PASS] test_redeem((address[4],uint256[4],uint256[4],int256),uint256,uint256) (runs: 5000, μ: 1226176, ~: 1225776)
[PASS] test_totalAssets((address[4],uint256[4],uint256[4],int256)) (runs: 5001, μ: 1071442, ~: 1071798)
[PASS] test_withdraw((address[4],uint256[4],uint256[4],int256),uint256,uint256) (runs: 5000, μ: 1228128, ~: 1227729)
Suite result: ok. 27 passed; 0 failed; 0 skipped; finished in 98.93s (699.72s CPU time)

╭--------------------------------------------------------+-----------------+-------+--------+-------+---------╮
| contracts/mocks/token/ERC20Mock.sol:ERC20Mock Contract |                 |       |        |       |         |
+=============================================================================================================+
| Deployment Cost                                        | Deployment Size |       |        |       |         |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| 532675                                                 | 2447            |       |        |       |         |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                        |                 |       |        |       |         |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                          | Min             | Avg   | Median | Max   | # Calls |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| allowance                                              | 833             | 833   | 833    | 833   | 1024    |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| approve                                                | 26395           | 36333 | 26395  | 46679 | 59392   |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| balanceOf                                              | 559             | 2344  | 2559   | 2559  | 39425   |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| burn                                                   | 34259           | 34394 | 34379  | 34631 | 1320    |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| decimals                                               | 265             | 265   | 265    | 265   | 283     |
|--------------------------------------------------------+-----------------+-------+--------+-------+---------|
| mint                                                   | 28328           | 51447 | 51088  | 68728 | 58584   |
╰--------------------------------------------------------+-----------------+-------+--------+-------+---------╯

╭------------------------------------------------------------+-----------------+-------+--------+--------+---------╮
| contracts/mocks/token/ERC4626Mock.sol:ERC4626Mock Contract |                 |       |        |        |         |
+==================================================================================================================+
| Deployment Cost                                            | Deployment Size |       |        |        |         |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| 1092940                                                    | 5529            |       |        |        |         |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
|                                                            |                 |       |        |        |         |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| Function Name                                              | Min             | Avg   | Median | Max    | # Calls |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| allowance                                                  | 800             | 800   | 800    | 800    | 1024    |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| approve                                                    | 26230           | 33059 | 26458  | 46742  | 3072    |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| asset                                                      | 284             | 284   | 284    | 284    | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| balanceOf                                                  | 572             | 572   | 572    | 572    | 2048    |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| convertToAssets                                            | 29939           | 30144 | 29963  | 30626  | 512     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| convertToShares                                            | 29961           | 30179 | 29997  | 30648  | 512     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| deposit                                                    | 45396           | 74937 | 67660  | 102133 | 28160   |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| maxDeposit                                                 | 389             | 389   | 389    | 389    | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| maxMint                                                    | 411             | 411   | 411    | 411    | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| maxRedeem                                                  | 626             | 626   | 626    | 626    | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| maxWithdraw                                                | 2494            | 2602  | 2494   | 2797   | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| mint                                                       | 45574           | 57172 | 56822  | 74513  | 1536    |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| previewDeposit                                             | 29982           | 30153 | 30006  | 30645  | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| previewMint                                                | 30002           | 30171 | 30026  | 30653  | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| previewRedeem                                              | 29960           | 30144 | 29984  | 30623  | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| previewWithdraw                                            | 30026           | 30164 | 30050  | 30677  | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| redeem                                                     | 24421           | 52683 | 55547  | 78714  | 1792    |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| totalAssets                                                | 1145            | 1145  | 1145   | 1145   | 256     |
|------------------------------------------------------------+-----------------+-------+--------+--------+---------|
| withdraw                                                   | 32877           | 55405 | 57837  | 80617  | 1792    |
╰------------------------------------------------------------+-----------------+-------+--------+--------+---------╯

╭---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------╮
| test/token/ERC20/extensions/ERC4626.t.sol:ERC4626VaultOffsetMock Contract |                 |     |        |     |         |
+============================================================================================================================+
| Deployment Cost                                                           | Deployment Size |     |        |     |         |
|---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| 1089637                                                                   | 5609            |     |        |     |         |
|---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
|                                                                           |                 |     |        |     |         |
|---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| Function Name                                                             | Min             | Avg | Median | Max | # Calls |
|---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| decimals                                                                  | 294             | 294 | 294    | 294 | 256     |
╰---------------------------------------------------------------------------+-----------------+-----+--------+-----+---------╯


Ran 1 test suite in 100.01s (98.93s CPU time): 27 tests passed, 0 failed, 0 skipped (27 total tests)
"""
    print()
    expected = {'passed': 27, 'failed': 0, 'total': 27, 'fails': {}}
    result = parse_forge_stdout(gas_report3)
    assert result == expected, "parse_forge_stdout did not produce expected result for gas_report 3"
    # print("Parse result:", result)
    expected = {'testFail_redeem((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1200331, '~': 1202793}, 'testFail_withdraw((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1205594, '~': 1207648}, 'testFuzzDecimalsOverflow(uint8)': {'-': 1133386, '~': 1133551}, 'test_RT_deposit_redeem((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1267473, '~': 1268419}, 'test_RT_deposit_withdraw((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1270410, '~': 1270376}, 'test_RT_mint_redeem((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1268525, '~': 1268512}, 'test_RT_mint_withdraw((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1271149, '~': 1270487}, 'test_RT_redeem_deposit((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1269067, '~': 1268512}, 'test_RT_redeem_mint((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1268986, '~': 1268437}, 'test_RT_withdraw_deposit((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1270570, '~': 1270446}, 'test_RT_withdraw_mint((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1271388, '~': 1270449}, 'test_asset((address[4],uint256[4],uint256[4],int256))': {'-': 1070723, '~': 1071025}, 'test_convertToAssets((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1133144, '~': 1133108}, 'test_convertToShares((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1133298, '~': 1133198}, 'test_deposit((address[4],uint256[4],uint256[4],int256),uint256,uint256)': {'-': 1223921, '~': 1224424}, 'test_maxDeposit((address[4],uint256[4],uint256[4],int256))': {'-': 1070960, '~': 1071094}, 'test_maxMint((address[4],uint256[4],uint256[4],int256))': {'-': 1070582, '~': 1071067}, 'test_maxRedeem((address[4],uint256[4],uint256[4],int256))': {'-': 1071048, '~': 1071286}, 'test_maxWithdraw((address[4],uint256[4],uint256[4],int256))': {'-': 1072871, '~': 1073200}, 'test_mint((address[4],uint256[4],uint256[4],int256),uint256,uint256)': {'-': 1224324, '~': 1224598}, 'test_previewDeposit((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1242733, '~': 1242937}, 'test_previewMint((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1243402, '~': 1243105}, 'test_previewRedeem((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1244488, '~': 1243677}, 'test_previewWithdraw((address[4],uint256[4],uint256[4],int256),uint256)': {'-': 1246289, '~': 1245648}, 'test_redeem((address[4],uint256[4],uint256[4],int256),uint256,uint256)': {'-': 1226176, '~': 1225776}, 'test_totalAssets((address[4],uint256[4],uint256[4],int256))': {'-': 1071442, '~': 1071798}, 'test_withdraw((address[4],uint256[4],uint256[4],int256),uint256,uint256)': {'-': 1228128, '~': 1227729}}
    gas_fees = extract_gas_fees_from_stdout(gas_report3)
    assert gas_fees == expected, "extract_gas_fees_from_stdout did not produce expected gas fees for gas_report 3"
    print(f"Gas fees from gas report 3: {gas_fees}. Total entries: {len(gas_fees)}")

    stdput = """No files changed, compilation skipped
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)

Ran 7 tests for test/utils/math/SignedMath.t.sol:SignedMathTest
[PASS] testAverage1(int256,int256) (runs: 5015, μ: 12265, ~: 12154)
[PASS] testAverage2(int256,int256) (runs: 5015, μ: 4975, ~: 4975)
[PASS] testSymbolicAbs(int256) (runs: 5015, μ: 3274, ~: 3273)
[PASS] testSymbolicMax(int256,int256) (runs: 5015, μ: 4218, ~: 4213)
[PASS] testSymbolicMin(int256,int256) (runs: 5015, μ: 4152, ~: 4147)
[PASS] testSymbolicMinMax(int256,int256) (runs: 5015, μ: 3887, ~: 3888)
[PASS] testSymbolicTernary(bool,int256,int256) (runs: 5015, μ: 3317, ~: 3318)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 272.24ms (858.96ms CPU time)
proptest: Aborting shrinking after the PROPTEST_MAX_SHRINK_ITERS environment variable or ProptestConfig.max_shrink_iters iterations (set 0 to a large(r) value to shrink more; current configuration: 0 iterations)

Ran 18 tests for test/utils/math/Math.t.sol:MathTest
[PASS] testCeilDiv(uint256,uint256) (runs: 5015, μ: 4057, ~: 4062)
[FAIL: assertion failed: 0 != 1; counterexample: calldata=0x9935f5c500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001 args=[1, 1]] testInvMod(uint256,uint256) (runs: 14, μ: 10243, ~: 9486)
[PASS] testInvMod17(uint256) (runs: 5015, μ: 8599, ~: 8672)
[PASS] testInvMod2(uint256) (runs: 5015, μ: 8161, ~: 8168)
[PASS] testInvMod65537(uint256) (runs: 5015, μ: 9289, ~: 9331)
[PASS] testInvModP256(uint256) (runs: 5015, μ: 15524, ~: 10768)
[PASS] testLog10(uint256,uint8) (runs: 5007, μ: 5983, ~: 6168)
[PASS] testLog2(uint256,uint8) (runs: 5007, μ: 5720, ~: 5876)
[FAIL: assertion failed; counterexample: calldata=0xb2c84a130000000000000000000000000000000000000000000000000000000001ceee750000000000000000000000000000000000000000000000000000000000000002 args=[30338677 [3.033e7], 2]] testLog256(uint256,uint8) (runs: 0, μ: 0, ~: 0)
[PASS] testModExp(uint256,uint256,uint256) (runs: 5015, μ: 20002, ~: 10448)
[PASS] testModExpMemory(uint256,uint256,uint256) (runs: 5015, μ: 24149, ~: 15310)
[PASS] testMulDiv(uint256,uint256,uint256) (runs: 5011, μ: 6599, ~: 6534)
[FAIL: Error != expected error: MathOverflowedMulDiv() != panic: division or modulo by zero (0x12); counterexample: calldata=0xddfdebbd000000000004ea7777558fbae7563f769d8f4176130ef65de577d29dda0eb7e20000000000000000005273cd5c2b684faccdc48944b6e5f3ddce6bdfb958cb990000000000000000000000000000000000000000000000000000000000000000 args=[2022277960850988963089319471546571676689837159473330909480925154 [2.022e63], 7897366389171524765166241954148184983852533433541118873 [7.897e54], 0]] testMulDivDomain(uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
[FAIL: assertion failed; counterexample: calldata=0x9090e658fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc0000000000000000000000000000000000000000000000000000000000000001 args=[115792089237316195423570985008687907853269984665640564039457584007913129639932 [1.157e77], 1]] testSqrt(uint256,uint8) (runs: 4, μ: 5704, ~: 6053)
[PASS] testSymbolicMinMax(uint256,uint256) (runs: 5015, μ: 3907, ~: 3908)
[PASS] testSymbolicTernary(bool,uint256,uint256) (runs: 5015, μ: 3349, ~: 3350)
[PASS] testTryModExp(uint256,uint256,uint256) (runs: 5015, μ: 20215, ~: 10680)
[PASS] testTryModExpMemory(uint256,uint256,uint256) (runs: 5015, μ: 24631, ~: 15633)
Suite result: FAILED. 14 passed; 4 failed; 0 skipped; finished in 765.25ms (3.91s CPU time)

Ran 2 test suites in 765.77ms (1.04s CPU time): 21 tests passed, 4 failed, 0 skipped (25 total tests)

Failing tests:
Encountered 4 failing tests in test/utils/math/Math.t.sol:MathTest
[FAIL: assertion failed: 0 != 1; counterexample: calldata=0x9935f5c500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001 args=[1, 1]] testInvMod(uint256,uint256) (runs: 14, μ: 10243, ~: 9486)
[FAIL: assertion failed; counterexample: calldata=0xb2c84a130000000000000000000000000000000000000000000000000000000001ceee750000000000000000000000000000000000000000000000000000000000000002 args=[30338677 [3.033e7], 2]] testLog256(uint256,uint8) (runs: 0, μ: 0, ~: 0)
[FAIL: Error != expected error: MathOverflowedMulDiv() != panic: division or modulo by zero (0x12); counterexample: calldata=0xddfdebbd000000000004ea7777558fbae7563f769d8f4176130ef65de577d29dda0eb7e20000000000000000005273cd5c2b684faccdc48944b6e5f3ddce6bdfb958cb990000000000000000000000000000000000000000000000000000000000000000 args=[2022277960850988963089319471546571676689837159473330909480925154 [2.022e63], 7897366389171524765166241954148184983852533433541118873 [7.897e54], 0]] testMulDivDomain(uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
[FAIL: assertion failed; counterexample: calldata=0x9090e658fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc0000000000000000000000000000000000000000000000000000000000000001 args=[115792089237316195423570985008687907853269984665640564039457584007913129639932 [1.157e77], 1]] testSqrt(uint256,uint8) (runs: 4, μ: 5704, ~: 6053)

Encountered a total of 4 failing tests, 21 tests succeeded
"""
    print()
    expected = {'passed': 21, 'failed': 4, 'total': 25, 'fails': {'testInvMod(uint256,uint256)': '[FAIL: assertion failed: 0 != 1; counterexample: calldata=0x9935f5c500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001 args=[1, 1]] testInvMod(uint256,uint256)', 'testLog256(uint256,uint8)': '[FAIL: assertion failed; counterexample: calldata=0xb2c84a130000000000000000000000000000000000000000000000000000000001ceee750000000000000000000000000000000000000000000000000000000000000002 args=[30338677 [3.033e7], 2]] testLog256(uint256,uint8)', 'testMulDivDomain(uint256,uint256,uint256)': '[FAIL: Error != expected error: MathOverflowedMulDiv() != panic: division or modulo by zero (0x12); counterexample: calldata=0xddfdebbd000000000004ea7777558fbae7563f769d8f4176130ef65de577d29dda0eb7e20000000000000000005273cd5c2b684faccdc48944b6e5f3ddce6bdfb958cb990000000000000000000000000000000000000000000000000000000000000000 args=[2022277960850988963089319471546571676689837159473330909480925154 [2.022e63], 7897366389171524765166241954148184983852533433541118873 [7.897e54], 0]] testMulDivDomain(uint256,uint256,uint256)', 'testSqrt(uint256,uint8)': '[FAIL: assertion failed; counterexample: calldata=0x9090e658fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc0000000000000000000000000000000000000000000000000000000000000001 args=[115792089237316195423570985008687907853269984665640564039457584007913129639932 [1.157e77], 1]] testSqrt(uint256,uint8)'}}
    result = parse_forge_stdout(stdput)
    assert result == expected, "parse_forge_stdout did not produce expected result for stdput"
    # print("Parse result:", result)
    print("All checks passed.")
    
