pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

library strings {
    struct slice {
        uint256 _len;
        uint256 _start;
        string _str;
    }

    function toSlice(string memory s) internal pure returns (slice memory) {
        return slice(bytes(s).length, 0, s);
    }

    function len(slice memory s) internal pure returns (uint256) {
        return s._len;
    }

    function toString(slice memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s._str);
        bytes memory out = new bytes(s._len);
        for (uint256 i = 0; i < s._len; i++) {
            out[i] = b[s._start + i];
        }
        return string(out);
    }

    function _indexOf(bytes memory hay, bytes memory needle, uint256 start) private pure returns (int256) {
        if (needle.length == 0) {
            return int256(start);
        }
        if (needle.length > hay.length) {
            return -1;
        }
        for (uint256 i = start; i <= hay.length - needle.length; i++) {
            bool match = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return int256(i);
            }
        }
        return -1;
    }

    function count(slice memory s, slice memory delim) internal pure returns (uint256) {
        bytes memory hay = bytes(s._str);
        bytes memory needle = bytes(toString(delim));
        if (needle.length == 0) {
            return 0;
        }
        uint256 occurrences = 0;
        uint256 pos = s._start;
        uint256 end = s._start + s._len;
        while (pos < end) {
            int256 idx = _indexOf(hay, needle, pos);
            if (idx < 0 || uint256(uint256(idx)) >= end) break;
            occurrences++;
            pos = uint256(uint256(idx)) + needle.length;
        }
        return occurrences + 1;
    }

    function split(slice memory s, slice memory delim) internal pure returns (slice memory token) {
        bytes memory hay = bytes(s._str);
        bytes memory needle = bytes(toString(delim));
        if (needle.length == 0) {
            token = slice(s._len, s._start, s._str);
            s._len = 0;
            return token;
        }
        int256 idx = _indexOf(hay, needle, s._start);
        if (idx < 0 || uint256(uint256(idx)) >= s._start + s._len) {
            // return whole slice and set s to empty
            token = slice(s._len, s._start, s._str);
            s._len = 0;
            return token;
        }
        uint256 uidx = uint256(uint256(idx));
        token = slice(uidx - s._start, s._start, s._str);
        uint256 newStart = uidx + needle.length;
        uint256 oldEnd = s._start + s._len;
        if (newStart >= oldEnd) {
            s._len = 0;
        } else {
            s._len = oldEnd - newStart;
            s._start = newStart;
        }
        return token;
    }
}

interface Vm {
    struct FfiResult {
        int256 exitCode;
        bytes stdout;
        bytes stderr;
    }

    function ffi(string[] calldata) external returns (FfiResult memory);

    function getenv(string calldata) external returns (string memory);

    function readFile(string calldata) external returns (string memory);

    function projectRoot() external returns (string memory);
}

library Utils {
    address internal constant CHEATCODE_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    struct ContractInfo {
        string shortName;
        string fileName;
        string path;
        string license;
        string sourceCodeHash;
        string artifactPath;
    }

    /**
     * @notice Constructs the fully qualified name of a contract by combining its path and short name.
     */
    function getFullyQualifiedName(string memory contractName, string memory outDir) internal view returns (string memory) {
        ContractInfo memory info = getContractInfo(contractName, outDir);
        return string(abi.encodePacked(info.path, ":", info.shortName));
    }

    /**
     * @notice Retrieves contract information from the artifact file.
     */
    function getContractInfo(string memory contractName, string memory outDir) internal view returns (ContractInfo memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);

        ContractInfo memory info;
        info.shortName = _toShortName(contractName);
        info.fileName = _toFileName(contractName);

        // Construct artifact path: <projectRoot>/<outDir>/<fileName>/<shortName>.json
        string memory projectRoot = vm.projectRoot();
        string memory artifactPath = string(abi.encodePacked(projectRoot, "/", outDir, "/", info.fileName, "/", info.shortName, ".json"));
        info.artifactPath = artifactPath;

        string memory artifact = vm.readFile(artifactPath);
        bytes memory artB = bytes(artifact);

        // Basic check for AST presence
        if (_indexOf(artB, bytes('"ast"'), 0) < 0) {
            revert("artifact missing AST or not found");
        }

        // Parse absolutePath
        string memory absPath = _extractJsonString(artifact, "absolutePath");
        info.path = absPath;

        // Parse license if present
        string memory license = _extractJsonString(artifact, "license");
        info.license = license;

        // Parse source code hash - try "sourceMap" fields commonly used: look for "sourceMap" or "sourceHash" or "source"
        string memory sourceHash = _extractJsonString(artifact, "sourceMap");
        if (bytes(sourceHash).length == 0) {
            sourceHash = _extractJsonString(artifact, "sourceHash");
        }
        if (bytes(sourceHash).length == 0) {
            // fall back to extracting "ast" -> "sourceHash" not always present; attempt "deployedSourceMap"
            sourceHash = _extractJsonString(artifact, "deployedSourceMap");
        }
        info.sourceCodeHash = sourceHash;

        return info;
    }

    /**
     * @notice Retrieves the build-info file for a contract based on its source code hash.
     */
    function getBuildInfoFile(string memory sourceCodeHash, string memory contractName, string memory outDir) internal returns (string memory) {
        // Build a grep command to find the build-info JSON referencing the source code hash.
        // This command is intentionally conservative and looks through the out directory.
        string[] memory inputs = new string[](3);
        inputs[0] = "grep";
        inputs[1] = "-R";
        // Search for the source code hash string in the outDir
        inputs[2] = string(abi.encodePacked(sourceCodeHash, " ", outDir));
        Vm.FfiResult memory res = runAsBashCommand(inputs);

        string memory out = string(res.stdout);
        bytes memory bout = bytes(out);

        // Try to extract the first .json path from the output
        int256 idx = _indexOf(bout, bytes(".json"), 0);
        if (idx < 0) {
            revert("build-info file not found");
        }

        // Find the beginning of the path by scanning backwards for newline or start
        uint256 endPos = uint256(uint256(idx)) + 5; // include ".json"
        uint256 startPos = 0;
        for (uint256 i = uint256(uint256(idx)); i > 0; i--) {
            if (bout[i] == "\n"[0]) {
                startPos = i + 1;
                break;
            }
            if (i == 1) {
                startPos = 0;
                break;
            }
        }
        bytes memory pathBytes = new bytes(endPos - startPos);
        for (uint256 i = startPos; i < endPos; i++) {
            pathBytes[i - startPos] = bout[i];
        }
        string memory buildInfoPath = string(pathBytes);

        // Basic validation
        bytes memory bip = bytes(buildInfoPath);
        if (bip.length < 6) {
            revert("invalid build info path");
        }
        return buildInfoPath;
    }

    /**
     * @notice Retrieves the output directory for Foundry, with a fallback to the default directory if not specified.
     */
    function getOutDir() internal view returns (string memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory env = vm.getenv("FOUNDRY_OUT");
        if (bytes(env).length == 0) {
            return "out";
        }
        return env;
    }

    /**
     * @notice Splits a string slice into an array of strings based on a delimiter slice.
     */
    function _split(strings.slice memory inputSlice, strings.slice memory delimSlice) private pure returns (string[] memory) {
        uint256 parts = strings.count(inputSlice, delimSlice);
        string[] memory ret = new string[](parts);
        for (uint256 i = 0; i < parts; i++) {
            strings.slice memory token = strings.split(inputSlice, delimSlice);
            ret[i] = strings.toString(token);
        }
        return ret;
    }

    /**
     * @notice Converts a contract name string into a valid file name format.
     */
    function _toFileName(string memory contractName) private pure returns (string memory) {
        bytes memory b = bytes(contractName);
        // If ends with ".sol"
        if (_endsWith(b, bytes(".sol"))) {
            // extract file name without path (last segment)
            uint256 slash = _lastIndexOf(b, bytes("/"));
            if (slash == type(uint256).max) {
                return contractName;
            } else {
                uint256 start = slash + 1;
                bytes memory out = new bytes(b.length - start);
                for (uint256 i = start; i < b.length; i++) {
                    out[i - start] = b[i];
                }
                return string(out);
            }
        }

        // If contains single colon "path:ShortName", return first part (path)
        int256 col = _indexOf(b, bytes(":"), 0);
        if (col >= 0) {
            uint256 c = uint256(uint256(col));
            bytes memory out = new bytes(c);
            for (uint256 i = 0; i < c; i++) {
                out[i] = b[i];
            }
            return string(out);
        }

        // If ends with ".json" and looks like path segments, return second-to-last part
        if (_endsWith(b, bytes(".json"))) {
            // split by '/'
            uint256 parts = _countChar(b, bytes("/")[0]) + 1;
            if (parts > 1) {
                // find second to last segment bounds
                uint256 last = _lastIndexOf(b, bytes("/"));
                uint256 prev = _lastIndexOfPrefix(b, bytes("/"), last == type(uint256).max ? b.length : last);
                uint256 start = prev == type(uint256).max ? 0 : prev + 1;
                uint256 len = last - start;
                bytes memory out = new bytes(len);
                for (uint256 i = 0; i < len; i++) {
                    out[i] = b[start + i];
                }
                return string(out);
            }
        }

        revert("invalid contract name format for file name");
    }

    /**
     * @notice Converts a contract name string into a short name by removing file extensions and paths.
     */
    function _toShortName(string memory contractName) private pure returns (string memory) {
        bytes memory b = bytes(contractName);
        // If ends with .sol -> remove path and extension
        if (_endsWith(b, bytes(".sol"))) {
            uint256 slash = _lastIndexOf(b, bytes("/"));
            uint256 start = (slash == type(uint256).max) ? 0 : slash + 1;
            uint256 end = b.length - 4; // remove ".sol"
            bytes memory out = new bytes(end - start);
            for (uint256 i = start; i < end; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        // If contains "path:ShortName"
        int256 col = _indexOf(b, bytes(":"), 0);
        if (col >= 0) {
            uint256 c = uint256(uint256(col));
            uint256 start = c + 1;
            bytes memory out = new bytes(b.length - start);
            for (uint256 i = start; i < b.length; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        // If ends with .json, extract filename and strip .json
        if (_endsWith(b, bytes(".json"))) {
            uint256 slash = _lastIndexOf(b, bytes("/"));
            uint256 start = (slash == type(uint256).max) ? 0 : slash + 1;
            uint256 end = b.length - 5;
            bytes memory out = new bytes(end - start);
            for (uint256 i = start; i < end; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        revert("invalid contract name format for short name");
    }

    /**
     * @notice Converts an array of input strings into a Bash command format.
     */
    function toBashCommand(string[] memory inputs, string memory bashPath) internal pure returns (string[] memory) {
        string memory commandString = "";
        for (uint256 i = 0; i < inputs.length; i++) {
            if (i == 0) {
                commandString = inputs[i];
            } else {
                commandString = string(abi.encodePacked(commandString, " ", inputs[i]));
            }
        }
        string[] memory result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        result[2] = commandString;
        return result;
    }

    /**
     * @notice Executes a bash command using the provided inputs.
     */
    function runAsBashCommand(string[] memory inputs) internal returns (Vm.FfiResult memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory bashPath = vm.getenv("OPENZEPPELIN_BASH_PATH");
        if (bytes(bashPath).length == 0) {
            bashPath = "/bin/bash";
        }
        string[] memory cmd = toBashCommand(inputs, bashPath);
        Vm.FfiResult memory res = vm.ffi(cmd);
        if (res.exitCode != 0 && res.stdout.length == 0 && res.stderr.length == 0) {
            revert("bash execution failed with no output; set OPENZEPPELIN_BASH_PATH to a working bash");
        }
        return res;
    }

    // -----------------------
    // Internal helper methods
    // -----------------------

    function _extractJsonString(string memory json, string memory key) internal pure returns (string memory) {
        bytes memory jb = bytes(json);
        bytes memory k = bytes(string(abi.encodePacked('"', key, '"')));
        int256 keyIdx = _indexOf(jb, k, 0);
        if (keyIdx < 0) {
            return "";
        }
        uint256 idx = uint256(uint256(keyIdx));
        // find ':' after key
        uint256 colonPos = idx;
        while (colonPos < jb.length && jb[colonPos] != ":") {
            colonPos++;
        }
        if (colonPos >= jb.length) {
            return "";
        }
        // find first quote after colon
        uint256 quoteStart = colonPos;
        while (quoteStart < jb.length && jb[quoteStart] != '"') {
            quoteStart++;
        }
        if (quoteStart >= jb.length) {
            return "";
        }
        uint256 quoteEnd = quoteStart + 1;
        while (quoteEnd < jb.length && jb[quoteEnd] != '"') {
            // allow escaping? simplistic: stop at next quote
            quoteEnd++;
        }
        if (quoteEnd >= jb.length) {
            return "";
        }
        bytes memory out = new bytes(quoteEnd - quoteStart - 1);
        for (uint256 i = quoteStart + 1; i < quoteEnd; i++) {
            out[i - quoteStart - 1] = jb[i];
        }
        return string(out);
    }

    function _endsWith(bytes memory what, bytes memory tail) internal pure returns (bool) {
        if (tail.length > what.length) return false;
        for (uint256 i = 0; i < tail.length; i++) {
            if (what[what.length - tail.length + i] != tail[i]) return false;
        }
        return true;
    }

    function _lastIndexOf(bytes memory what, bytes memory needle) internal pure returns (uint256) {
        if (needle.length == 0) {
            return type(uint256).max;
        }
        for (uint256 i = what.length; i > 0; i--) {
            bool match = true;
            if (i < needle.length) continue;
            uint256 start = i - needle.length;
            for (uint256 j = 0; j < needle.length; j++) {
                if (what[start + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return i - needle.length;
            }
        }
        return type(uint256).max;
    }

    function _lastIndexOfPrefix(bytes memory what, bytes memory needle, uint256 before) internal pure returns (uint256) {
        if (needle.length == 0) {
            return type(uint256).max;
        }
        if (before == 0) {
            return type(uint256).max;
        }
        uint256 limit = before;
        for (uint256 i = limit; i > 0; i--) {
            bool match = true;
            if (i < needle.length) continue;
            uint256 start = i - needle.length;
            for (uint256 j = 0; j < needle.length; j++) {
                if (what[start + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return i - needle.length;
            }
        }
        return type(uint256).max;
    }

    function _countChar(bytes memory what, bytes1 ch) internal pure returns (uint256) {
        uint256 cnt = 0;
        for (uint256 i = 0; i < what.length; i++) {
            if (what[i] == ch) cnt++;
        }
        return cnt;
    }

    function _indexOf(bytes memory hay, bytes memory needle, uint256 start) internal pure returns (int256) {
        if (needle.length == 0) {
            return int256(start);
        }
        if (needle.length > hay.length) {
            return -1;
        }
        for (uint256 i = start; i <= hay.length - needle.length; i++) {
            bool match = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return int256(i);
            }
        }
        return -1;
    }
}
```// filepath: Utils.sol
pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

library strings {
    struct slice {
        uint256 _len;
        uint256 _start;
        string _str;
    }

    function toSlice(string memory s) internal pure returns (slice memory) {
        return slice(bytes(s).length, 0, s);
    }

    function len(slice memory s) internal pure returns (uint256) {
        return s._len;
    }

    function toString(slice memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s._str);
        bytes memory out = new bytes(s._len);
        for (uint256 i = 0; i < s._len; i++) {
            out[i] = b[s._start + i];
        }
        return string(out);
    }

    function _indexOf(bytes memory hay, bytes memory needle, uint256 start) private pure returns (int256) {
        if (needle.length == 0) {
            return int256(start);
        }
        if (needle.length > hay.length) {
            return -1;
        }
        for (uint256 i = start; i <= hay.length - needle.length; i++) {
            bool match = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return int256(i);
            }
        }
        return -1;
    }

    function count(slice memory s, slice memory delim) internal pure returns (uint256) {
        bytes memory hay = bytes(s._str);
        bytes memory needle = bytes(toString(delim));
        if (needle.length == 0) {
            return 0;
        }
        uint256 occurrences = 0;
        uint256 pos = s._start;
        uint256 end = s._start + s._len;
        while (pos < end) {
            int256 idx = _indexOf(hay, needle, pos);
            if (idx < 0 || uint256(uint256(idx)) >= end) break;
            occurrences++;
            pos = uint256(uint256(idx)) + needle.length;
        }
        return occurrences + 1;
    }

    function split(slice memory s, slice memory delim) internal pure returns (slice memory token) {
        bytes memory hay = bytes(s._str);
        bytes memory needle = bytes(toString(delim));
        if (needle.length == 0) {
            token = slice(s._len, s._start, s._str);
            s._len = 0;
            return token;
        }
        int256 idx = _indexOf(hay, needle, s._start);
        if (idx < 0 || uint256(uint256(idx)) >= s._start + s._len) {
            // return whole slice and set s to empty
            token = slice(s._len, s._start, s._str);
            s._len = 0;
            return token;
        }
        uint256 uidx = uint256(uint256(idx));
        token = slice(uidx - s._start, s._start, s._str);
        uint256 newStart = uidx + needle.length;
        uint256 oldEnd = s._start + s._len;
        if (newStart >= oldEnd) {
            s._len = 0;
        } else {
            s._len = oldEnd - newStart;
            s._start = newStart;
        }
        return token;
    }
}

interface Vm {
    struct FfiResult {
        int256 exitCode;
        bytes stdout;
        bytes stderr;
    }

    function ffi(string[] calldata) external returns (FfiResult memory);

    function getenv(string calldata) external returns (string memory);

    function readFile(string calldata) external returns (string memory);

    function projectRoot() external returns (string memory);
}

library Utils {
    address internal constant CHEATCODE_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    struct ContractInfo {
        string shortName;
        string fileName;
        string path;
        string license;
        string sourceCodeHash;
        string artifactPath;
    }

    /**
     * @notice Constructs the fully qualified name of a contract by combining its path and short name.
     */
    function getFullyQualifiedName(string memory contractName, string memory outDir) internal view returns (string memory) {
        ContractInfo memory info = getContractInfo(contractName, outDir);
        return string(abi.encodePacked(info.path, ":", info.shortName));
    }

    /**
     * @notice Retrieves contract information from the artifact file.
     */
    function getContractInfo(string memory contractName, string memory outDir) internal view returns (ContractInfo memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);

        ContractInfo memory info;
        info.shortName = _toShortName(contractName);
        info.fileName = _toFileName(contractName);

        // Construct artifact path: <projectRoot>/<outDir>/<fileName>/<shortName>.json
        string memory projectRoot = vm.projectRoot();
        string memory artifactPath = string(abi.encodePacked(projectRoot, "/", outDir, "/", info.fileName, "/", info.shortName, ".json"));
        info.artifactPath = artifactPath;

        string memory artifact = vm.readFile(artifactPath);
        bytes memory artB = bytes(artifact);

        // Basic check for AST presence
        if (_indexOf(artB, bytes('"ast"'), 0) < 0) {
            revert("artifact missing AST or not found");
        }

        // Parse absolutePath
        string memory absPath = _extractJsonString(artifact, "absolutePath");
        info.path = absPath;

        // Parse license if present
        string memory license = _extractJsonString(artifact, "license");
        info.license = license;

        // Parse source code hash - try "sourceMap" fields commonly used: look for "sourceMap" or "sourceHash" or "source"
        string memory sourceHash = _extractJsonString(artifact, "sourceMap");
        if (bytes(sourceHash).length == 0) {
            sourceHash = _extractJsonString(artifact, "sourceHash");
        }
        if (bytes(sourceHash).length == 0) {
            // fall back to extracting "ast" -> "sourceHash" not always present; attempt "deployedSourceMap"
            sourceHash = _extractJsonString(artifact, "deployedSourceMap");
        }
        info.sourceCodeHash = sourceHash;

        return info;
    }

    /**
     * @notice Retrieves the build-info file for a contract based on its source code hash.
     */
    function getBuildInfoFile(string memory sourceCodeHash, string memory contractName, string memory outDir) internal returns (string memory) {
        // Build a grep command to find the build-info JSON referencing the source code hash.
        // This command is intentionally conservative and looks through the out directory.
        string[] memory inputs = new string[](3);
        inputs[0] = "grep";
        inputs[1] = "-R";
        // Search for the source code hash string in the outDir
        inputs[2] = string(abi.encodePacked(sourceCodeHash, " ", outDir));
        Vm.FfiResult memory res = runAsBashCommand(inputs);

        string memory out = string(res.stdout);
        bytes memory bout = bytes(out);

        // Try to extract the first .json path from the output
        int256 idx = _indexOf(bout, bytes(".json"), 0);
        if (idx < 0) {
            revert("build-info file not found");
        }

        // Find the beginning of the path by scanning backwards for newline or start
        uint256 endPos = uint256(uint256(idx)) + 5; // include ".json"
        uint256 startPos = 0;
        for (uint256 i = uint256(uint256(idx)); i > 0; i--) {
            if (bout[i] == "\n"[0]) {
                startPos = i + 1;
                break;
            }
            if (i == 1) {
                startPos = 0;
                break;
            }
        }
        bytes memory pathBytes = new bytes(endPos - startPos);
        for (uint256 i = startPos; i < endPos; i++) {
            pathBytes[i - startPos] = bout[i];
        }
        string memory buildInfoPath = string(pathBytes);

        // Basic validation
        bytes memory bip = bytes(buildInfoPath);
        if (bip.length < 6) {
            revert("invalid build info path");
        }
        return buildInfoPath;
    }

    /**
     * @notice Retrieves the output directory for Foundry, with a fallback to the default directory if not specified.
     */
    function getOutDir() internal view returns (string memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory env = vm.getenv("FOUNDRY_OUT");
        if (bytes(env).length == 0) {
            return "out";
        }
        return env;
    }

    /**
     * @notice Splits a string slice into an array of strings based on a delimiter slice.
     */
    function _split(strings.slice memory inputSlice, strings.slice memory delimSlice) private pure returns (string[] memory) {
        uint256 parts = strings.count(inputSlice, delimSlice);
        string[] memory ret = new string[](parts);
        for (uint256 i = 0; i < parts; i++) {
            strings.slice memory token = strings.split(inputSlice, delimSlice);
            ret[i] = strings.toString(token);
        }
        return ret;
    }

    /**
     * @notice Converts a contract name string into a valid file name format.
     */
    function _toFileName(string memory contractName) private pure returns (string memory) {
        bytes memory b = bytes(contractName);
        // If ends with ".sol"
        if (_endsWith(b, bytes(".sol"))) {
            // extract file name without path (last segment)
            uint256 slash = _lastIndexOf(b, bytes("/"));
            if (slash == type(uint256).max) {
                return contractName;
            } else {
                uint256 start = slash + 1;
                bytes memory out = new bytes(b.length - start);
                for (uint256 i = start; i < b.length; i++) {
                    out[i - start] = b[i];
                }
                return string(out);
            }
        }

        // If contains single colon "path:ShortName", return first part (path)
        int256 col = _indexOf(b, bytes(":"), 0);
        if (col >= 0) {
            uint256 c = uint256(uint256(col));
            bytes memory out = new bytes(c);
            for (uint256 i = 0; i < c; i++) {
                out[i] = b[i];
            }
            return string(out);
        }

        // If ends with ".json" and looks like path segments, return second-to-last part
        if (_endsWith(b, bytes(".json"))) {
            // split by '/'
            uint256 parts = _countChar(b, bytes("/")[0]) + 1;
            if (parts > 1) {
                // find second to last segment bounds
                uint256 last = _lastIndexOf(b, bytes("/"));
                uint256 prev = _lastIndexOfPrefix(b, bytes("/"), last == type(uint256).max ? b.length : last);
                uint256 start = prev == type(uint256).max ? 0 : prev + 1;
                uint256 len = last - start;
                bytes memory out = new bytes(len);
                for (uint256 i = 0; i < len; i++) {
                    out[i] = b[start + i];
                }
                return string(out);
            }
        }

        revert("invalid contract name format for file name");
    }

    /**
     * @notice Converts a contract name string into a short name by removing file extensions and paths.
     */
    function _toShortName(string memory contractName) private pure returns (string memory) {
        bytes memory b = bytes(contractName);
        // If ends with .sol -> remove path and extension
        if (_endsWith(b, bytes(".sol"))) {
            uint256 slash = _lastIndexOf(b, bytes("/"));
            uint256 start = (slash == type(uint256).max) ? 0 : slash + 1;
            uint256 end = b.length - 4; // remove ".sol"
            bytes memory out = new bytes(end - start);
            for (uint256 i = start; i < end; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        // If contains "path:ShortName"
        int256 col = _indexOf(b, bytes(":"), 0);
        if (col >= 0) {
            uint256 c = uint256(uint256(col));
            uint256 start = c + 1;
            bytes memory out = new bytes(b.length - start);
            for (uint256 i = start; i < b.length; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        // If ends with .json, extract filename and strip .json
        if (_endsWith(b, bytes(".json"))) {
            uint256 slash = _lastIndexOf(b, bytes("/"));
            uint256 start = (slash == type(uint256).max) ? 0 : slash + 1;
            uint256 end = b.length - 5;
            bytes memory out = new bytes(end - start);
            for (uint256 i = start; i < end; i++) {
                out[i - start] = b[i];
            }
            return string(out);
        }

        revert("invalid contract name format for short name");
    }

    /**
     * @notice Converts an array of input strings into a Bash command format.
     */
    function toBashCommand(string[] memory inputs, string memory bashPath) internal pure returns (string[] memory) {
        string memory commandString = "";
        for (uint256 i = 0; i < inputs.length; i++) {
            if (i == 0) {
                commandString = inputs[i];
            } else {
                commandString = string(abi.encodePacked(commandString, " ", inputs[i]));
            }
        }
        string[] memory result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        result[2] = commandString;
        return result;
    }

    /**
     * @notice Executes a bash command using the provided inputs.
     */
    function runAsBashCommand(string[] memory inputs) internal returns (Vm.FfiResult memory) {
        Vm vm = Vm(CHEATCODE_ADDRESS);
        string memory bashPath = vm.getenv("OPENZEPPELIN_BASH_PATH");
        if (bytes(bashPath).length == 0) {
            bashPath = "/bin/bash";
        }
        string[] memory cmd = toBashCommand(inputs, bashPath);
        Vm.FfiResult memory res = vm.ffi(cmd);
        if (res.exitCode != 0 && res.stdout.length == 0 && res.stderr.length == 0) {
            revert("bash execution failed with no output; set OPENZEPPELIN_BASH_PATH to a working bash");
        }
        return res;
    }

    // -----------------------
    // Internal helper methods
    // -----------------------

    function _extractJsonString(string memory json, string memory key) internal pure returns (string memory) {
        bytes memory jb = bytes(json);
        bytes memory k = bytes(string(abi.encodePacked('"', key, '"')));
        int256 keyIdx = _indexOf(jb, k, 0);
        if (keyIdx < 0) {
            return "";
        }
        uint256 idx = uint256(uint256(keyIdx));
        // find ':' after key
        uint256 colonPos = idx;
        while (colonPos < jb.length && jb[colonPos] != ":") {
            colonPos++;
        }
        if (colonPos >= jb.length) {
            return "";
        }
        // find first quote after colon
        uint256 quoteStart = colonPos;
        while (quoteStart < jb.length && jb[quoteStart] != '"') {
            quoteStart++;
        }
        if (quoteStart >= jb.length) {
            return "";
        }
        uint256 quoteEnd = quoteStart + 1;
        while (quoteEnd < jb.length && jb[quoteEnd] != '"') {
            // allow escaping? simplistic: stop at next quote
            quoteEnd++;
        }
        if (quoteEnd >= jb.length) {
            return "";
        }
        bytes memory out = new bytes(quoteEnd - quoteStart - 1);
        for (uint256 i = quoteStart + 1; i < quoteEnd; i++) {
            out[i - quoteStart - 1] = jb[i];
        }
        return string(out);
    }

    function _endsWith(bytes memory what, bytes memory tail) internal pure returns (bool) {
        if (tail.length > what.length) return false;
        for (uint256 i = 0; i < tail.length; i++) {
            if (what[what.length - tail.length + i] != tail[i]) return false;
        }
        return true;
    }

    function _lastIndexOf(bytes memory what, bytes memory needle) internal pure returns (uint256) {
        if (needle.length == 0) {
            return type(uint256).max;
        }
        for (uint256 i = what.length; i > 0; i--) {
            bool match = true;
            if (i < needle.length) continue;
            uint256 start = i - needle.length;
            for (uint256 j = 0; j < needle.length; j++) {
                if (what[start + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return i - needle.length;
            }
        }
        return type(uint256).max;
    }

    function _lastIndexOfPrefix(bytes memory what, bytes memory needle, uint256 before) internal pure returns (uint256) {
        if (needle.length == 0) {
            return type(uint256).max;
        }
        if (before == 0) {
            return type(uint256).max;
        }
        uint256 limit = before;
        for (uint256 i = limit; i > 0; i--) {
            bool match = true;
            if (i < needle.length) continue;
            uint256 start = i - needle.length;
            for (uint256 j = 0; j < needle.length; j++) {
                if (what[start + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return i - needle.length;
            }
        }
        return type(uint256).max;
    }

    function _countChar(bytes memory what, bytes1 ch) internal pure returns (uint256) {
        uint256 cnt = 0;
        for (uint256 i = 0; i < what.length; i++) {
            if (what[i] == ch) cnt++;
        }
        return cnt;
    }

    function _indexOf(bytes memory hay, bytes memory needle, uint256 start) internal pure returns (int256) {
        if (needle.length == 0) {
            return int256(start);
        }
        if (needle.length > hay.length) {
            return -1;
        }
        for (uint256 i = start; i <= hay.length - needle.length; i++) {
            bool match = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return int256(i);
            }
        }
        return -1;
    }
}