// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple JSON parser library.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/JSONParserLib.sol)
library JSONParserLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Type constants.
    uint256 private constant TYPE_UNDEFINED = 0;
    uint256 private constant TYPE_OBJECT = 1;
    uint256 private constant TYPE_ARRAY = 2;
    uint256 private constant TYPE_STRING = 3;
    uint256 private constant TYPE_NUMBER = 4;
    uint256 private constant TYPE_BOOLEAN = 5;
    uint256 private constant TYPE_NULL = 6;

    /// @dev Bitmask constants.
    uint256 private constant _BITMASK_TYPE = 0x7;
    uint256 private constant _BITMASK_PARENT = (1 << 224) - 1;
    uint256 private constant _BITPOS_PARENT = 32;
    uint256 private constant _PARENT_IS_ARRAY = 1 << 3;
    uint256 private constant _PARENT_IS_OBJECT = 1 << 4;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Do NOT modify `_data` directly. It is for internal use only.
    struct Item {
        uint256 _data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The parsing has failed.
    error ParsingFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PARSING OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Parses the JSON string `s` into an item.
    function parse(string memory s) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result)
            result := _query(_toInput(s), 0xff)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      QUERY OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the value of `item`.
    function value(Item memory item) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := _query(_toInput(item), 0)
        }
    }

    /// @dev Returns the index of `item` if the parent is an array, else returns 0.
    function index(Item memory item) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := shr(8, mload(item))
            if iszero(and(mload(item), _PARENT_IS_ARRAY)) { result := 0 }
        }
    }

    /// @dev Returns the key of `item` if the parent is an object, else returns "".
    function key(Item memory item) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            if and(mload(item), _PARENT_IS_OBJECT) { result := _query(_toInput(item), 1) }
        }
    }

    /// @dev Returns the children of `item`.
    function children(Item memory item) internal pure returns (Item[] memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := _query(_toInput(item), 3)
        }
    }

    /// @dev Returns the number of children of `item`.
    function size(Item memory item) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let c := _query(_toInput(item), 3)
            result := mload(c)
        }
    }

    /// @dev Returns the child at index `i` of `item`.
    /// Returns the zero item if the index is out of bounds, or if `item` is not an array.
    function at(Item memory item, uint256 i) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result)
            let c := _query(_toInput(item), 3)
            result := 0x60
            if and(eq(and(mload(item), _BITMASK_TYPE), TYPE_ARRAY), lt(i, mload(c))) {
                result := add(add(c, 0x20), shl(5, i))
            }
        }
    }

    /// @dev Returns the child with key `k` of `item`.
    /// Returns the zero item if the key is not found, or if `item` is not an object.
    function at(Item memory item, string memory k) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result)
            let c := _query(_toInput(item), 3)
            result := 0x60
            if eq(and(mload(item), _BITMASK_TYPE), TYPE_OBJECT) {
                let n := mload(c)
                let h := keccak256(add(k, 0x20), mload(k))
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    let child := add(add(c, 0x20), shl(5, i))
                    let childKey := _query(mload(child), 1)
                    if eq(keccak256(add(childKey, 0x20), mload(childKey)), h) {
                        result := child
                        break
                    }
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       TYPE OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the type of `item`.
    function getType(Item memory item) internal pure returns (uint8 result) {
        result = uint8(item._data & _BITMASK_TYPE);
    }

    /// @dev Returns if `item` is undefined.
    function isUndefined(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_UNDEFINED;
    }

    /// @dev Returns if `item` is an array.
    function isArray(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_ARRAY;
    }

    /// @dev Returns if `item` is an object.
    function isObject(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_OBJECT;
    }

    /// @dev Returns if `item` is a number.
    function isNumber(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_NUMBER;
    }

    /// @dev Returns if `item` is a string.
    function isString(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_STRING;
    }

    /// @dev Returns if `item` is a boolean.
    function isBoolean(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_BOOLEAN;
    }

    /// @dev Returns if `item` is null.
    function isNull(Item memory item) internal pure returns (bool result) {
        result = (item._data & _BITMASK_TYPE) == TYPE_NULL;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    HIERARCHY OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the parent of `item`. Returns the zero item if `item` has no parent.
    function parent(Item memory item) internal pure returns (Item memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x40, result)
            result := shr(_BITPOS_PARENT, mload(item))
            if iszero(result) { result := 0x60 }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PARSING UTILITIES                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Parses `s` as an unsigned integer.
    function parseUint(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let preMulOverflowThres := div(not(0), 10)
            let p := add(s, 0x20)
            for {} 1 {} {
                let c := byte(0, mload(p))
                c := sub(c, 48)
                if gt(result, preMulOverflowThres) { break }
                result := add(mul(result, 10), c)
                n := add(n, lt(9, or(c, n)))
                p := add(p, 1)
                if iszero(n) { break }
            }
            if n {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Parses `s` as a signed integer.
    function parseInt(string memory s) internal pure returns (int256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            if iszero(n) {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
            let p := add(s, 0x20)
            let c := byte(0, mload(p))
            let isNeg := eq(c, 45)
            if or(eq(c, 43), isNeg) {
                p := add(p, 1)
                n := sub(n, 1)
            }
            if iszero(n) {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(s, n)
            mstore(add(s, 0x20), mload(p))
            result := parseUint(s)
            if isNeg {
                result := not(result)
                if iszero(eq(result, not(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))) {
                    result := add(result, 1)
                }
                if slt(result, 0) {
                    mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            if iszero(isNeg) {
                if slt(result, 0) {
                    mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @dev Parses `s` as an unsigned integer from a hex string.
    function parseUintFromHex(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let p := add(s, 0x20)
            let c := byte(0, mload(p))
            if eq(c, 48) {
                c := byte(0, mload(add(p, 1)))
                if or(eq(c, 0x78), eq(c, 0x58)) {
                    p := add(p, 2)
                    n := sub(n, 2)
                }
            }
            for {} 1 {} {
                c := byte(0, mload(p))
                c := or(shl(8, or(lt(c, 58), lt(70, c))), c)
                c := sub(c, shl(8, mul(gt(c, 0x466), 7)))
                c := sub(and(c, 0xff), 48)
                result := or(shl(4, result), c)
                n := add(n, lt(15, or(c, n)))
                p := add(p, 1)
                if iszero(n) { break }
            }
            if n {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Decodes a JSON string with escape sequences.
    function decodeString(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            function fail() {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
            let n := mload(s)
            if iszero(gt(n, 1)) { fail() }
            let p := add(s, 0x20)
            if iszero(eq(byte(0, mload(p)), 34)) { fail() }
            if iszero(eq(byte(0, mload(add(p, sub(n, 1)))), 34)) { fail() }
            result := mload(0x40)
            let o := add(result, 0x20)
            p := add(p, 1)
            let end := add(p, sub(n, 2))
            for {} lt(p, end) {} {
                let c := byte(0, mload(p))
                p := add(p, 1)
                if eq(c, 92) {
                    c := byte(0, mload(p))
                    p := add(p, 1)
                    if eq(c, 34) { c := 34 }
                    if eq(c, 92) { c := 92 }
                    if eq(c, 47) { c := 47 }
                    if eq(c, 98) { c := 8 }
                    if eq(c, 102) { c := 12 }
                    if eq(c, 110) { c := 10 }
                    if eq(c, 114) { c := 13 }
                    if eq(c, 116) { c := 9 }
                    if eq(c, 117) {
                        let u := 0
                        for { let i := 0 } lt(i, 4) { i := add(i, 1) } {
                            c := byte(0, mload(p))
                            p := add(p, 1)
                            c := or(shl(8, or(lt(c, 58), lt(70, c))), c)
                            c := sub(c, shl(8, mul(gt(c, 0x466), 7)))
                            c := sub(and(c, 0xff), 48)
                            if gt(c, 15) { fail() }
                            u := or(shl(4, u), c)
                        }
                        if lt(u, 0x80) {
                            mstore8(o, u)
                            o := add(o, 1)
                            continue
                        }
                        if lt(u, 0x800) {
                            mstore8(o, or(0xc0, shr(6, u)))
                            o := add(o, 1)
                            mstore8(o, or(0x80, and(u, 0x3f)))
                            o := add(o, 1)
                            continue
                        }
                        mstore8(o, or(0xe0, shr(12, u)))
                        o := add(o, 1)
                        mstore8(o, or(0x80, and(shr(6, u), 0x3f)))
                        o := add(o, 1)
                        mstore8(o, or(0x80, and(u, 0x3f)))
                        o := add(o, 1)
                        continue
                    }
                }
                mstore8(o, c)
                o := add(o, 1)
            }
            mstore(result, sub(o, add(result, 0x20)))
            mstore(0x40, add(o, 0x1f))
            mstore(o, 0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The main query function that handles parsing and querying operations.
    function _query(bytes32 input, uint256 mode) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            function fail() {
                mstore(0x00, 0x5802d2c0) // `ParsingFailed()`.
                revert(0x1c, 0x04)
            }
            function chr(p_) -> _c {
                _c := byte(0, mload(p_))
            }
            function skipWhitespace(pIn_, end_) -> _pIn {
                _pIn := pIn_
                for {} 1 {} {
                    if iszero(lt(_pIn, end_)) { break }
                    let c := chr(_pIn)
                    if iszero(or(or(eq(c, 0x20), eq(c, 0x09)), or(eq(c, 0x0a), eq(c, 0x0d)))) {
                        break
                    }
                    _pIn := add(_pIn, 1)
                }
            }
            function setP(packed_, bitpos_, p_) -> _packed {
                _packed := or(and(packed_, not(shl(bitpos_, _BITMASK_PARENT))), shl(bitpos_, p_))
            }
            function getP(packed_, bitpos_) -> _p {
                _p := and(shr(bitpos_, packed_), _BITMASK_PARENT)
            }
            function mallocItem(s_, packed_, pStart_, pCurr_, type_) -> _item {
                _item := mload(0x40)
                mstore(0x40, add(_item, 0x20))
                let d := or(or(and(packed_, not(31)), type_), shl(8, sub(pCurr_, pStart_)))
                mstore(_item, or(d, shl(5, sub(mload(s_), 0x20))))
                mstore(s_, _item)
            }
            function parseValue(s_, sibling_, pIn_, end_) -> _pIn {
                _pIn := skipWhitespace(pIn_, end_)
                if iszero(lt(_pIn, end_)) { fail() }
                let c := chr(_pIn)
                if eq(c, 0x7b) {
                    _pIn := parseObject(s_, sibling_, add(_pIn, 1), end_)
                    leave
                }
                if eq(c, 0x5b) {
                    _pIn := parseArray(s_, sibling_, add(_pIn, 1), end_)
                    leave
                }
                if eq(c, 0x22) {
                    _pIn := parseStringSub(s_, sibling_, _pIn, end_)
                    leave
                }
                if or(eq(c, 0x2d), and(lt(c, 0x3a), gt(c, 0x2f))) {
                    _pIn := parseNumber(s_, sibling_, _pIn, end_)
                    leave
                }
                if eq(c, 0x74) {
                    if iszero(lt(add(_pIn, 3), end_)) { fail() }
                    if iszero(eq(and(mload(_pIn), 0xffffffff), 0x74727565)) { fail() }
                    mallocItem(s_, sibling_, _pIn, add(_pIn, 4), TYPE_BOOLEAN)
                    _pIn := add(_pIn, 4)
                    leave
                }
                if eq(c, 0x66) {
                    if iszero(lt(add(_pIn, 4), end_)) { fail() }
                    if iszero(eq(and(mload(_pIn), 0xffffffffff), 0x66616c7365)) { fail() }
                    mallocItem(s_, sibling_, _pIn, add(_pIn, 5), TYPE_BOOLEAN)
                    _pIn := add(_pIn, 5)
                    leave
                }
                if eq(c, 0x6e) {
                    if iszero(lt(add(_pIn, 3), end_)) { fail() }
                    if iszero(eq(and(mload(_pIn), 0xffffffff), 0x6e756c6c)) { fail() }
                    mallocItem(s_, sibling_, _pIn, add(_pIn, 4), TYPE_NULL)
                    _pIn := add(_pIn, 4)
                    leave
                }
                fail()
            }
            function parseArray(s_, packed_, pIn_, end_) -> _pIn {
                let array := mallocItem(s_, packed_, sub(pIn_, 1), sub(pIn_, 1), TYPE_ARRAY)
                packed_ := setP(packed_, _BITPOS_PARENT, array)
                packed_ := or(and(packed_, not(0x18)), _PARENT_IS_ARRAY)
                _pIn := skipWhitespace(pIn_, end_)
                if iszero(lt(_pIn, end_)) { fail() }
                if eq(chr(_pIn), 0x5d) {
                    _pIn := add(_pIn, 1)
                    leave
                }
                for {} 1 {} {
                    _pIn := parseValue(s_, packed_, _pIn, end_)
                    _pIn := skipWhitespace(_pIn, end_)
                    if iszero(lt(_pIn, end_)) { fail() }
                    let c := chr(_pIn)
                    _pIn := add(_pIn, 1)
                    if eq(c, 0x5d) { break }
                    if iszero(eq(c, 0x2c)) { fail() }
                    packed_ := add(packed_, 0x100)
                }
            }
            function parseObject(s_, packed_, pIn_, end_) -> _pIn {
                let object := mallocItem(s_, packed_, sub(pIn_, 1), sub(pIn_, 1), TYPE_OBJECT)
                packed_ := setP(packed_, _BITPOS_PARENT, object)
                packed_ := or(and(packed_, not(0x18)), _PARENT_IS_OBJECT)
                _pIn := skipWhitespace(pIn_, end_)
                if iszero(lt(_pIn, end_)) { fail() }
                if eq(chr(_pIn), 0x7d) {
                    _pIn := add(_pIn, 1)
                    leave
                }
                for {} 1 {} {
                    _pIn := skipWhitespace(_pIn, end_)
                    if iszero(lt(_pIn, end_)) { fail() }
                    if iszero(eq(chr(_pIn), 0x22)) { fail() }
                    let pKey := _pIn
                    _pIn := parseStringSub(s_, packed_, _pIn, end_)
                    let item := mload(s_)
                    mstore(item, or(mload(item), shl(5, sub(pKey, 0x20))))
                    _pIn := skipWhitespace(_pIn, end_)
                    if iszero(lt(_pIn, end_)) { fail() }
                    if iszero(eq(chr(_pIn), 0x3a)) { fail() }
                    _pIn := parseValue(s_, packed_, add(_pIn, 1), end_)
                    _pIn := skipWhitespace(_pIn, end_)
                    if iszero(lt(_pIn, end_)) { fail() }
                    let c := chr(_pIn)
                    _pIn := add(_pIn, 1)
                    if eq(c, 0x7d) { break }
                    if iszero(eq(c, 0x2c)) { fail() }
                    packed_ := add(packed_, 0x100)
                }
            }
            function checkStringU(p_, o_) {
                if iszero(lt(add(p_, 3), o_)) { fail() }
                for { let i := 0 } lt(i, 4) { i := add(i, 1) } {
                    let c := chr(add(p_, i))
                    c := or(shl(8, or(lt(c, 58), lt(70, c))), c)
                    c := sub(c, shl(8, mul(gt(c, 0x466), 7)))
                    c := sub(and(c, 0xff), 48)
                    if gt(c, 15) { fail() }
                }
            }
            function parseStringSub(s_, packed_, pIn_, end_) -> _pIn {
                let pStart := pIn_
                _pIn := add(_pIn, 1)
                for {} 1 {} {
                    if iszero(lt(_pIn, end_)) { fail() }
                    let c := chr(_pIn)
                    if eq(c, 0x22) {
                        mallocItem(s_, packed_, pStart, add(_pIn, 1), TYPE_STRING)
                        _pIn := add(_pIn, 1)
                        break
                    }
                    if eq(c, 92) {
                        _pIn := add(_pIn, 1)
                        if iszero(lt(_pIn, end_)) { fail() }
                        c := chr(_pIn)
                        if eq(c, 0x75) { checkStringU(add(_pIn, 1), end_) }
                    }
                    _pIn := add(_pIn, 1)
                }
            }
            function skip0To9s(pIn_, end_, atLeastOne_) -> _pIn {
                _pIn := pIn_
                for {} 1 {} {
                    if iszero(lt(_pIn, end_)) { break }
                    let c := chr(_pIn)
                    if or(lt(c, 48), gt(c, 57)) { break }
                    _pIn := add(_pIn, 1)
                    atLeastOne_ := 0
                }
                if atLeastOne_ { fail() }
            }
            function parseNumber(s_, packed_, pIn_, end_) -> _pIn {
                let pStart := pIn_
                if eq(chr(_pIn), 0x2d) { _pIn := add(_pIn, 1) }
                if iszero(lt(_pIn, end_)) { fail() }
                let c := chr(_pIn)
                if eq(c, 48) {
                    _pIn := add(_pIn, 1)
                }
                if and(lt(c, 0x3a), gt(c, 0x30)) { _pIn := skip0To9s(add(_pIn, 1), end_, 0) }
                if iszero(eq(sub(_pIn, pStart), 1)) {
                    if eq(chr(pStart), 48) { fail() }
                }
                if iszero(lt(_pIn, end_)) {
                    mallocItem(s_, packed_, pStart, _pIn, TYPE_NUMBER)
                    leave
                }
                c := chr(_pIn)
                if eq(c, 0x2e) {
                    _pIn := skip0To9s(add(_pIn, 1), end_, 1)
                    if iszero(lt(_pIn, end_)) {
                        mallocItem(s_, packed_, pStart, _pIn, TYPE_NUMBER)
                        leave
                    }
                    c := chr(_pIn)
                }
                if or(eq(c, 0x65), eq(c, 0x45)) {
                    _pIn := add(_pIn, 1)
                    if iszero(lt(_pIn, end_)) { fail() }
                    c := chr(_pIn)
                    if or(eq(c, 0x2b), eq(c, 0x2d)) { _pIn := add(_pIn, 1) }
                    _pIn := skip0To9s(_pIn, end_, 1)
                }
                mallocItem(s_, packed_, pStart, _pIn, TYPE_NUMBER)
            }
            function copyStr(s_, offset_, len_) -> _result {
                _result := mload(0x40)
                let o := add(_result, 0x20)
                let p := add(add(s_, 0x20), offset_)
                for { let i := 0 } lt(i, len_) { i := add(i, 0x20) } {
                    mstore(add(o, i), mload(add(p, i)))
                }
                mstore(_result, len_)
                mstore(0x40, add(add(o, len_), 0x1f))
                mstore(add(o, len_), 0)
            }
            function value(item_) -> _result {
                let d := mload(item_)
                let s := and(shr(5, d), _BITMASK_PARENT)
                let offset := and(shr(8, d), 0xffffff)
                let len := sub(and(shr(8, shr(32, d)), 0xffffff), offset)
                _result := copyStr(s, offset, len)
            }
            function children(item_) -> _result {
                let d := mload(item_)
                let s := and(shr(5, d), _BITMASK_PARENT)
                let startOffset := add(s, 0x20)
                let endOffset := add(mload(s), 0x20)
                let n := 0
                for { let i := startOffset } lt(i, endOffset) { i := add(i, 0x20) } {
                    let child := mload(i)
                    if eq(and(shr(_BITPOS_PARENT, child), _BITMASK_PARENT), item_) {
                        n := add(n, 1)
                    }
                }
                _result := mload(0x40)
                mstore(_result, n)
                mstore(0x40, add(add(_result, 0x20), shl(5, n)))
                let o := add(_result, 0x20)
                for { let i := startOffset } lt(i, endOffset) { i := add(i, 0x20) } {
                    let child := mload(i)
                    if eq(and(shr(_BITPOS_PARENT, child), _BITMASK_PARENT), item_) {
                        mstore(o, child)
                        o := add(o, 0x20)
                    }
                }
            }
            function getStr(item_, bitpos_, bitposLength_, bitmaskInited_) -> _result {
                let d := mload(item_)
                if iszero(and(d, bitmaskInited_)) {
                    _result := mload(0x40)
                    mstore(_result, 0)
                    mstore(add(_result, 0x20), 0)
                    mstore(0x40, add(_result, 0x40))
                    leave
                }
                let s := and(shr(5, d), _BITMASK_PARENT)
                let offset := and(shr(bitpos_, d), 0xffffff)
                let len := sub(and(shr(bitposLength_, d), 0xffffff), offset)
                _result := copyStr(s, offset, len)
            }
            let s := and(shr(5, input), _BITMASK_PARENT)
            if eq(mode, 0xff) {
                let pIn := add(s, 0x20)
                let end := add(pIn, mload(s))
                mstore(s, sub(mload(0x40), 0x20))
                pIn := parseValue(s, 0, pIn, end_)
                pIn := skipWhitespace(pIn, end)
                if iszero(eq(pIn, end)) { fail() }
                result := mload(s)
                leave
            }
            if iszero(mode) {
                result := value(input)
                leave
            }
            if eq(mode, 1) {
                result := getStr(input, 8, 40, _PARENT_IS_OBJECT)
                leave
            }
            result := children(input)
        }
    }

    /// @dev Converts a string to a bytes32 input.
    function _toInput(string memory input) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := shl(5, input)
        }
    }

    /// @dev Converts an item to a bytes32 input.
    function _toInput(Item memory input) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(input)
        }
    }
}
