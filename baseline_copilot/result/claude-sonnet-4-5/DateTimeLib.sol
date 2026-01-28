// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for date time operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DateTimeLib.sol)
library DateTimeLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 internal constant MON = 1;
    uint256 internal constant TUE = 2;
    uint256 internal constant WED = 3;
    uint256 internal constant THU = 4;
    uint256 internal constant FRI = 5;
    uint256 internal constant SAT = 6;
    uint256 internal constant SUN = 7;

    uint256 internal constant SECS_PER_DAY = 86400;
    uint256 internal constant SECS_PER_HOUR = 3600;
    uint256 internal constant SECS_PER_MINUTE = 60;

    uint256 internal constant OFFSET_1970 = 719468;

    uint256 internal constant MAX_SUPPORTED_YEAR = 2149;
    uint256 internal constant MAX_SUPPORTED_EPOCH_DAY = 65535;
    uint256 internal constant MAX_SUPPORTED_TIMESTAMP = 5662310399;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DATE TIME OPERATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Converts a given date (year, month, day) into the number of days since the Unix epoch (January 1, 1970).
     *
     * @param year The year component of the date.
     * @param month The month component of the date.
     * @param day The day component of the date.
     *
     * @return epochDay The number of days since the Unix epoch corresponding to the given date.
     *
     * Steps:
     * 1. Adjust the year if the month is before March (to account for leap years).
     * 2. Calculate the day of the year (doy) based on the month and day.
     * 3. Calculate the year of the era (yoe) by taking the year modulo 400.
     * 4. Calculate the day of the era (doe) by combining the year of the era, leap years, and the day of the year.
     * 5. Compute the total number of days since the Unix epoch by combining the number of full 400-year cycles and the day of the era, then adjust for the epoch offset.
     *
     * @dev This function uses low-level assembly for efficient date-to-epoch conversion.
     */
    function dateToEpochDay(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 epochDay)
    {
        assembly {
            year := sub(year, lt(month, 3))
            let doy := add(sub(div(add(mul(month, 979), 30671), 32), 1), day)
            let yoe := mod(year, 400)
            let doe := sub(add(add(mul(yoe, 365), shr(2, yoe)), doy), div(yoe, 100))
            epochDay := sub(add(mul(div(year, 400), 146097), doe), OFFSET_1970)
        }
    }

    /**
     * @notice Converts a given epoch day (days since 1970-01-01) to a date in the format of year, month, and day.
     * @dev This function uses low-level assembly for efficient date calculation. It handles leap years and month lengths.
     *
     * @param epochDay The number of days since 1970-01-01 (Unix epoch).
     * @return year The calculated year.
     * @return month The calculated month (1-12).
     * @return day The calculated day of the month (1-31).
     *
     * Steps:
     * 1. Adjust the epoch day by adding 719468 to align with the Gregorian calendar.
     * 2. Calculate the day of the era (doe) by taking the modulo of the adjusted epoch day with 146097 (400 years in days).
     * 3. Compute the year of the era (yoe) by dividing and adjusting for leap years.
     * 4. Calculate the day of the year (doy) by subtracting the days accounted for by the year of the era.
     * 5. Determine the month (mp) and day by dividing and adjusting the day of the year.
     * 6. Extract the month and day from precomputed values using bitwise operations.
     * 7. Calculate the final year by adding the year of the era and adjusting for the month.
     */
    function epochDayToDate(uint256 epochDay)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        assembly {
            epochDay := add(epochDay, OFFSET_1970)
            let doe := mod(epochDay, 146097)
            let yoe := div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(yoe, 365), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(doy, 5), 2), 153)
            day := add(sub(doy, shr(32, mul(mp, 2141672801))), 1)
            month := byte(mp, 0x0c01020304050607080900000a0b0000)
            year := add(add(yoe, mul(div(epochDay, 146097), 400)), gt(month, 10))
        }
    }

    /**
     * @notice Converts a given date (year, month, day) into a Unix timestamp.
     *
     * @param year The year component of the date.
     * @param month The month component of the date.
     * @param day The day component of the date.
     * @return result The Unix timestamp corresponding to the provided date.
     *
     * Steps:
     * 1. Calculate the number of days since the Unix epoch (January 1, 1970) using `dateToEpochDay`.
     * 2. Multiply the result by 86400 (the number of seconds in a day) to convert days into seconds.
     * 3. Return the resulting Unix timestamp.
     *
     * Note: The function uses `unchecked` to disable overflow checks, assuming the inputs are valid.
     */
    function dateToTimestamp(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = dateToEpochDay(year, month, day) * SECS_PER_DAY;
        }
    }

    /**
     * @notice Converts a Unix timestamp to a date (year, month, day).
     *
     * @param timestamp The Unix timestamp to convert.
     * @return year The year corresponding to the timestamp.
     * @return month The month corresponding to the timestamp.
     * @return day The day corresponding to the timestamp.
     *
     * Steps:
     * 1. Divide the timestamp by 86400 (seconds in a day) to get the number of days since the Unix epoch.
     * 2. Pass the result to `epochDayToDate` to convert it into a year, month, and day.
     */
    function timestampToDate(uint256 timestamp)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        (year, month, day) = epochDayToDate(timestamp / SECS_PER_DAY);
    }

    /**
     * @notice Converts a given date and time into a Unix timestamp.
     *
     * @param year The year component of the date.
     * @param month The month component of the date.
     * @param day The day component of the date.
     * @param hour The hour component of the time.
     * @param minute The minute component of the time.
     * @param second The second component of the time.
     *
     * @return result The Unix timestamp representing the given date and time.
     *
     * Steps:
     * 1. Calculate the number of days since the Unix epoch (January 1, 1970) using the `dateToEpochDay` function.
     * 2. Multiply the number of days by 86400 (seconds in a day) to get the total seconds for the days.
     * 3. Add the seconds equivalent of the hour, minute, and second components.
     * 4. Return the resulting Unix timestamp.
     *
     * Note: The function uses `unchecked` to avoid overflow checks, assuming the inputs are valid.
     */
    function dateTimeToTimestamp(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (uint256 result) {
        unchecked {
            result = dateToEpochDay(year, month, day) * SECS_PER_DAY + hour * SECS_PER_HOUR
                + minute * SECS_PER_MINUTE + second;
        }
    }

    /**
     * @notice Converts a Unix timestamp into a human-readable date and time format.
     *
     * @param timestamp The Unix timestamp to be converted.
     * @return year The year component of the timestamp.
     * @return month The month component of the timestamp.
     * @return day The day component of the timestamp.
     * @return hour The hour component of the timestamp.
     * @return minute The minute component of the timestamp.
     * @return second The second component of the timestamp.
     *
     * Steps:
     * 1. Divide the timestamp by 86400 (seconds in a day) to get the number of days since the epoch.
     * 2. Use the `epochDayToDate` function to convert the number of days into year, month, and day.
     * 3. Calculate the remaining seconds after extracting the days.
     * 4. Convert the remaining seconds into hours, minutes, and seconds.
     * 5. Return the calculated year, month, day, hour, minute, and second.
     */
    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        )
    {
        unchecked {
            (year, month, day) = epochDayToDate(timestamp / SECS_PER_DAY);
            uint256 secs = timestamp % SECS_PER_DAY;
            hour = secs / SECS_PER_HOUR;
            secs = secs % SECS_PER_HOUR;
            minute = secs / SECS_PER_MINUTE;
            second = secs % SECS_PER_MINUTE;
        }
    }

    /**
     * @notice Determines if a given year is a leap year using low-level assembly for efficiency.
     *
     * @param year The year to check for leap year status.
     * @return leap A boolean indicating whether the year is a leap year (true) or not (false).
     *
     * Steps:
     * 1. Use inline assembly to perform the leap year calculation:
     *    - Check if the year is divisible by 25.
     *    - Perform bitwise operations to determine if the year is a leap year.
     * 2. Return the result of the calculation.
     *
     * Note: This function uses Solidity's assembly block for low-level optimization.
     */
    function isLeapYear(uint256 year) internal pure returns (bool leap) {
        assembly {
            leap := iszero(and(shl(4, div(year, 25)), add(year, shl(2, iszero(mod(year, 25))))))
        }
    }

    /**
     * @notice Calculates the number of days in a given month and year, taking leap years into account.
     *
     * @param year The year for which the calculation is performed.
     * @param month The month for which the number of days is calculated.
     * @return result The number of days in the specified month and year.
     *
     * Steps:
     * 1. Check if the provided year is a leap year using the `isLeapYear` function.
     * 2. Use inline assembly to efficiently calculate the number of days:
     *    - A lookup table for the number of days in each month is embedded in the assembly code.
     *    - Adjust for February in leap years by adding 1 if the month is February and the year is a leap year.
     * 3. Return the calculated number of days.
     *
     * @dev The assembly code uses a packed representation of the days in each month and adjusts for leap years.
     */
    function daysInMonth(uint256 year, uint256 month) internal pure returns (uint256 result) {
        bool leap = isLeapYear(year);
        assembly {
            result := add(byte(month, 0x001f1e1f001f1e1f1e1f1e1f1e000000), and(eq(month, 2), leap))
        }
    }

    /**
     * @notice Calculates the day of the week (1-7) for a given Unix timestamp.
     *
     * @param timestamp The Unix timestamp for which to determine the weekday.
     * @return result The day of the week, where 1 = Monday, 2 = Tuesday, ..., 7 = Sunday.
     *
     * Steps:
     * 1. Divide the timestamp by the number of seconds in a day (86400) to get the number of days since the Unix epoch.
     * 2. Add 3 to the result to adjust for the fact that January 1, 1970, was a Thursday.
     * 3. Take modulo 7 to get the day of the week (0-6).
     * 4. Add 1 to convert the range from 0-6 to 1-7, where 1 represents Monday and 7 represents Sunday.
     *
     * Note: The `unchecked` block is used to disable overflow checks for better gas efficiency.
     */
    function weekday(uint256 timestamp) internal pure returns (uint256 result) {
        unchecked {
            result = ((timestamp / SECS_PER_DAY + 3) % 7) + 1;
        }
    }

    /**
     * @notice Checks if the provided date (year, month, day) is supported by the system.
     *
     * @param year The year to check.
     * @param month The month to check.
     * @param day The day to check.
     * @return result A boolean indicating whether the date is supported.
     *
     * Steps:
     * 1. Calculate the number of days in the provided month and year using `daysInMonth`.
     * 2. Use inline assembly to perform the following checks:
     *    - Ensure the year is within the supported range (1970 to MAX_SUPPORTED_YEAR).
     *    - Ensure the month is within the range of 1 to 12.
     *    - Ensure the day is within the range of 1 to the number of days in the month.
     * 3. Return `true` if all checks pass, otherwise `false`.
     */
    function isSupportedDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (bool result)
    {
        uint256 md = daysInMonth(year, month);
        assembly {
            result :=
                and(
                    and(lt(sub(year, 1970), sub(MAX_SUPPORTED_YEAR, 1969)), lt(sub(month, 1), 12)),
                    lt(sub(day, 1), md)
                )
        }
    }

    /**
     * @notice Checks if the provided date and time values are supported.
     *
     * @param year The year value to check.
     * @param month The month value to check.
     * @param day The day value to check.
     * @param hour The hour value to check.
     * @param minute The minute value to check.
     * @param second The second value to check.
     *
     * @return result A boolean indicating whether the provided date and time values are valid.
     *
     * Steps:
     * 1. First, check if the provided date (year, month, day) is valid using the `isSupportedDate` function.
     * 2. If the date is valid, use inline assembly to check if the time values (hour, minute, second) are within valid ranges:
     *    - Hour must be less than 24.
     *    - Minute must be less than 60.
     *    - Second must be less than 60.
     * 3. Return `true` if all values are valid, otherwise return `false`.
     */
    function isSupportedDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (bool result) {
        if (isSupportedDate(year, month, day)) {
            assembly {
                result := and(lt(hour, 24), and(lt(minute, 60), lt(second, 60)))
            }
        }
    }

    /**
     * @notice Checks if the provided epoch day is within the supported range.
     *
     * @param epochDay The epoch day to check.
     * @return result A boolean indicating whether the epoch day is supported (true if supported, false otherwise).
     *
     * Steps:
     * 1. Perform an unchecked operation to avoid overflow/underflow checks.
     * 2. Compare the provided `epochDay` with the maximum supported epoch day (`MAX_SUPPORTED_EPOCH_DAY`).
     * 3. Return `true` if the `epochDay` is less than or equal to `MAX_SUPPORTED_EPOCH_DAY`, otherwise return `false`.
     */
    function isSupportedEpochDay(uint256 epochDay) internal pure returns (bool result) {
        unchecked {
            result = epochDay <= MAX_SUPPORTED_EPOCH_DAY;
        }
    }

    /**
     * @notice Checks if a given timestamp is within the supported range.
     *
     * @param timestamp The timestamp to be checked.
     * @return result A boolean indicating whether the timestamp is supported (true) or not (false).
     *
     * Steps:
     * 1. Perform an unchecked operation to avoid overflow/underflow checks.
     * 2. Compare the provided timestamp against the maximum supported timestamp.
     * 3. Return true if the timestamp is less than or equal to the maximum supported timestamp, otherwise return false.
     */
    function isSupportedTimestamp(uint256 timestamp) internal pure returns (bool result) {
        unchecked {
            result = timestamp <= MAX_SUPPORTED_TIMESTAMP;
        }
    }

    /**
     * @notice Calculates the Unix timestamp for the nth occurrence of a specific weekday in a given month and year.
     *
     * @param year The year for which the calculation is performed.
     * @param month The month for which the calculation is performed.
     * @param n The nth occurrence of the weekday (e.g., 1st, 2nd, 3rd, etc.).
     * @param wd The weekday to find (0 = Sunday, 1 = Monday, ..., 6 = Saturday).
     *
     * @return result The Unix timestamp for the nth occurrence of the specified weekday in the given month and year.
     *                Returns 0 if the nth occurrence does not exist (e.g., if `n` is too large for the month).
     *
     * Steps:
     * 1. Calculate the epoch day for the first day of the given month and year.
     * 2. Determine the number of days in the given month.
     * 3. Use assembly to compute the date of the nth weekday:
     *    - Calculate the difference between the desired weekday and the weekday of the first day of the month.
     *    - Adjust the date based on the difference and the nth occurrence.
     *    - Ensure the calculated date is within the bounds of the month.
     * 4. Convert the calculated date to a Unix timestamp by multiplying by 86400 (seconds in a day).
     * 5. Return the result, or 0 if the nth occurrence does not exist.
     */
    function nthWeekdayInMonthOfYearTimestamp(uint256 year, uint256 month, uint256 n, uint256 wd)
        internal
        pure
        returns (uint256 result)
    {
        uint256 epochDay = dateToEpochDay(year, month, 1);
        uint256 md = daysInMonth(year, month);
        assembly {
            let w := add(mod(add(epochDay, 3), 7), 1)
            let d := add(mul(sub(n, 1), 7), add(iszero(wd), wd))
            d := add(d, mul(sub(7, add(w, sub(0, d))), gt(w, d)))
            result := mul(mul(SECS_PER_DAY, add(epochDay, sub(d, 1))), iszero(gt(d, md)))
        }
    }

    /**
     * @notice Calculates the timestamp of the most recent Monday at 00:00:00 UTC based on the given timestamp.
     *
     * @param timestamp The input timestamp from which to calculate the most recent Monday.
     * @return result The timestamp of the most recent Monday at 00:00:00 UTC.
     *
     * Steps:
     * 1. Divide the input timestamp by the number of seconds in a day (86400) to get the number of days since the Unix epoch.
     * 2. Calculate the day of the week by taking the modulus of the day count plus 3 (to align with Monday as the start of the week) and 7.
     * 3. Subtract the day of the week from the total day count to get the most recent Monday.
     * 4. Multiply the result by 86400 to convert it back to a timestamp.
     * 5. Ensure the result is valid by checking if the input timestamp is greater than 345599 (4 days in seconds, to handle edge cases).
     *
     * @dev This function uses inline assembly for efficient computation.
     */
    function mondayTimestamp(uint256 timestamp) internal pure returns (uint256 result) {
        assembly {
            let day := div(timestamp, SECS_PER_DAY)
            result := mul(SECS_PER_DAY, sub(day, mod(add(day, 3), 7)))
            result := mul(result, gt(timestamp, 345599))
        }
    }

    /**
     * @notice Checks if the given timestamp falls on a weekend.
     *
     * @param timestamp The timestamp to check.
     * @return result A boolean indicating whether the timestamp is on a weekend (true) or not (false).
     *
     * Steps:
     * 1. Call the `weekday` function to determine the day of the week for the given timestamp.
     * 2. Compare the result with `FRI` (Friday).
     * 3. Return `true` if the day is Saturday or Sunday (i.e., greater than Friday), otherwise return `false`.
     */
    function isWeekEnd(uint256 timestamp) internal pure returns (bool result) {
        result = weekday(timestamp) > FRI;
    }

    /**
     * @notice Adds a specified number of years to a given timestamp and returns the new timestamp.
     *
     * @param timestamp The original timestamp to which years will be added.
     * @param numYears The number of years to add to the timestamp.
     * @return result The new timestamp after adding the specified number of years.
     *
     * Steps:
     * 1. Convert the timestamp into a date format (year, month, day) using `epochDayToDate`.
     * 2. Add the specified number of years to the year component.
     * 3. Calculate the new timestamp using the `_offsetted` function with the updated year, month, day, and original timestamp.
     */
    function addYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / SECS_PER_DAY);
        result = _offsetted(year + numYears, month, day, timestamp);
    }

    /**
     * @notice Adds a specified number of months to a given timestamp and returns the resulting timestamp.
     *
     * @param timestamp The initial timestamp to which months will be added.
     * @param numMonths The number of months to add to the timestamp.
     * @return result The resulting timestamp after adding the specified number of months.
     *
     * Steps:
     * 1. Convert the timestamp into a date format (year, month, day) using `epochDayToDate`.
     * 2. Calculate the new month by adding `numMonths` to the current month and adjusting for overflow.
     * 3. Calculate the resulting timestamp by converting the updated date back into a timestamp using `_offsetted`.
     */
    function addMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / SECS_PER_DAY);
        uint256 totalMonths = _totalMonths(year, month) + numMonths;
        unchecked {
            result = _offsetted(totalMonths / 12, (totalMonths % 12) + 1, day, timestamp);
        }
    }

    /**
     * @notice Adds a specified number of days to a given timestamp.
     *
     * @param timestamp The initial timestamp to which days will be added.
     * @param numDays The number of days to add to the timestamp.
     * @return result The new timestamp after adding the specified number of days.
     *
     * Steps:
     * 1. Calculate the new timestamp by adding the number of days multiplied by 86400 (seconds in a day) to the initial timestamp.
     * 2. Return the resulting timestamp.
     */
    function addDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numDays * SECS_PER_DAY;
        }
    }

    /**
     * @notice Adds a specified number of hours to a given timestamp.
     *
     * @param timestamp The initial timestamp to which hours will be added.
     * @param numHours The number of hours to add to the timestamp.
     * @return result The new timestamp after adding the specified hours.
     *
     * Steps:
     * 1. Calculate the new timestamp by adding the number of hours multiplied by 3600 (seconds in an hour) to the original timestamp.
     * 2. Return the resulting timestamp.
     */
    function addHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numHours * SECS_PER_HOUR;
        }
    }

    /**
     * @notice Adds a specified number of minutes to a given timestamp.
     *
     * @param timestamp The initial timestamp to which minutes will be added.
     * @param numMinutes The number of minutes to add to the timestamp.
     * @return result The new timestamp after adding the specified minutes.
     *
     * Steps:
     * 1. Calculate the result by adding the product of `numMinutes` and 60 (seconds) to the `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function addMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp + numMinutes * SECS_PER_MINUTE;
        }
    }

    /**
     * @notice Adds a specified number of seconds to a given timestamp.
     *
     * @param timestamp The initial timestamp to which seconds will be added.
     * @param numSeconds The number of seconds to add to the timestamp.
     * @return result The new timestamp after adding the specified number of seconds.
     *
     * Steps:
     * 1. Calculate the result by adding `numSeconds` to the `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function addSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp + numSeconds;
        }
    }

    /**
     * @notice Subtracts a specified number of years from a given timestamp and returns the resulting timestamp.
     *
     * @param timestamp The original timestamp from which years are to be subtracted.
     * @param numYears The number of years to subtract from the timestamp.
     * @return result The new timestamp after subtracting the specified number of years.
     *
     * Steps:
     * 1. Convert the given timestamp into a date format (year, month, day) using the `epochDayToDate` function.
     * 2. Subtract the specified number of years from the year component.
     * 3. Calculate the new timestamp by adjusting the year, month, and day components using the `_offsetted` function.
     */
    function subYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / SECS_PER_DAY);
        result = _offsetted(year - numYears, month, day, timestamp);
    }

    /**
     * @notice Subtracts a specified number of months from a given timestamp.
     *
     * @param timestamp The starting timestamp from which months will be subtracted.
     * @param numMonths The number of months to subtract from the timestamp.
     * @return result The resulting timestamp after subtracting the specified number of months.
     *
     * Steps:
     * 1. Convert the timestamp into a date format (year, month, day) using `epochDayToDate`.
     * 2. Calculate the total months since epoch by calling `_totalMonths` and subtract the specified number of months.
     * 3. Adjust the year and month values based on the subtraction result.
     * 4. Calculate the resulting timestamp by calling `_offsetted` with the adjusted year, month, day, and original timestamp.
     */
    function subMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / SECS_PER_DAY);
        uint256 totalMonths = _totalMonths(year, month) - numMonths;
        unchecked {
            result = _offsetted(totalMonths / 12, (totalMonths % 12) + 1, day, timestamp);
        }
    }

    /**
     * @notice Subtracts a specified number of days from a given timestamp.
     *
     * @param timestamp The initial timestamp from which days will be subtracted.
     * @param numDays The number of days to subtract from the timestamp.
     * @return result The resulting timestamp after subtracting the specified number of days.
     *
     * Steps:
     * 1. Calculate the result by subtracting the number of seconds equivalent to `numDays` (1 day = 86400 seconds) from the `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function subDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numDays * SECS_PER_DAY;
        }
    }

    /**
     * @notice Subtracts a specified number of hours from a given timestamp.
     *
     * @param timestamp The original timestamp from which hours will be subtracted.
     * @param numHours The number of hours to subtract from the timestamp.
     * @return result The new timestamp after subtracting the specified number of hours.
     *
     * Steps:
     * 1. Calculate the result by subtracting `numHours * 3600` (seconds in an hour) from the `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function subHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numHours * SECS_PER_HOUR;
        }
    }

    /**
     * @notice Subtracts a specified number of minutes from a given timestamp.
     *
     * @param timestamp The original timestamp from which minutes will be subtracted.
     * @param numMinutes The number of minutes to subtract from the timestamp.
     * @return result The resulting timestamp after subtracting the specified minutes.
     *
     * Steps:
     * 1. Calculate the result by subtracting the total seconds equivalent of `numMinutes` from the `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function subMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp - numMinutes * SECS_PER_MINUTE;
        }
    }

    /**
     * @notice Subtracts a specified number of seconds from a given timestamp.
     *
     * @param timestamp The initial timestamp from which seconds will be subtracted.
     * @param numSeconds The number of seconds to subtract from the timestamp.
     * @return result The resulting timestamp after subtracting the specified number of seconds.
     *
     * Steps:
     * 1. Subtract `numSeconds` from `timestamp`.
     * 2. Return the resulting timestamp.
     */
    function subSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp - numSeconds;
        }
    }

    /**
     * @notice Calculates the difference in years between two timestamps.
     *
     * @param fromTimestamp The starting timestamp.
     * @param toTimestamp The ending timestamp.
     * @return result The difference in years between the two timestamps.
     *
     * Steps:
     * 1. Convert both timestamps to days since the epoch by dividing by 86400 (seconds in a day).
     * 2. Convert the days since the epoch to a date (year, month, day) using `epochDayToDate`.
     * 3. Extract the year from the date for both timestamps.
     * 4. Calculate the difference in years between the two extracted years using `_sub`.
     */
    function diffYears(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 fromYear,,) = epochDayToDate(fromTimestamp / SECS_PER_DAY);
        (uint256 toYear,,) = epochDayToDate(toTimestamp / SECS_PER_DAY);
        result = _sub(toYear, fromYear);
    }

    /**
     * @notice Calculates the difference in months between two timestamps.
     *
     * @param fromTimestamp The starting timestamp.
     * @param toTimestamp The ending timestamp.
     * @return result The number of months between the two timestamps.
     *
     * Steps:
     * 1. Convert the timestamps to days by dividing by 86400 (seconds in a day).
     * 2. Extract the year and month from the starting timestamp using `epochDayToDate`.
     * 3. Extract the year and month from the ending timestamp using `epochDayToDate`.
     * 4. Calculate the total months for both the starting and ending timestamps using `_totalMonths`.
     * 5. Subtract the total months of the starting timestamp from the total months of the ending timestamp to get the result.
     */
    function diffMonths(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 fromYear, uint256 fromMonth,) = epochDayToDate(fromTimestamp / SECS_PER_DAY);
        (uint256 toYear, uint256 toMonth,) = epochDayToDate(toTimestamp / SECS_PER_DAY);
        result = _sub(_totalMonths(toYear, toMonth), _totalMonths(fromYear, fromMonth));
    }

    /**
     * @notice Calculates the difference in days between two timestamps.
     *
     * @param fromTimestamp The starting timestamp.
     * @param toTimestamp The ending timestamp.
     * @return result The number of days between the two timestamps.
     *
     * Steps:
     * 1. Subtract the starting timestamp (`fromTimestamp`) from the ending timestamp (`toTimestamp`).
     * 2. Divide the result by 86400 (the number of seconds in a day) to get the difference in days.
     * 3. Return the calculated number of days.
     */
    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = (toTimestamp - fromTimestamp) / SECS_PER_DAY;
        }
    }

    /**
     * @notice Calculates the difference in hours between two timestamps.
     *
     * @param fromTimestamp The starting timestamp (in seconds).
     * @param toTimestamp The ending timestamp (in seconds).
     * @return result The difference in hours between the two timestamps.
     *
     * Steps:
     * 1. Subtract the `fromTimestamp` from the `toTimestamp` to get the difference in seconds.
     * 2. Divide the difference by 3600 (seconds in an hour) to convert it to hours.
     * 3. Return the result as an unsigned integer.
     */
    function diffHours(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = (toTimestamp - fromTimestamp) / SECS_PER_HOUR;
        }
    }

    /**
     * @notice Calculates the difference in minutes between two timestamps.
     *
     * @param fromTimestamp The starting timestamp.
     * @param toTimestamp The ending timestamp.
     * @return result The difference in minutes between the two timestamps.
     *
     * Steps:
     * 1. Subtract the `fromTimestamp` from the `toTimestamp` to get the difference in seconds.
     * 2. Divide the result by 60 to convert the difference from seconds to minutes.
     * 3. Return the result as an unsigned integer.
     */
    function diffMinutes(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = (toTimestamp - fromTimestamp) / SECS_PER_MINUTE;
        }
    }

    /**
     * @notice Calculates the difference in seconds between two timestamps.
     *
     * @param fromTimestamp The starting timestamp.
     * @param toTimestamp The ending timestamp.
     * @return result The difference in seconds between `toTimestamp` and `fromTimestamp`.
     *
     * Steps:
     * 1. Subtract `fromTimestamp` from `toTimestamp` to get the difference in seconds.
     * 2. Return the result.
     */
    function diffSeconds(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = toTimestamp - fromTimestamp;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Calculates the total number of months based on the given number of years and months.
     * @dev This function is private and pure, meaning it does not modify the state and can only be called internally.
     * @param numYears The number of years to convert into months.
     * @param numMonths The additional months to add to the total.
     * @return total The total number of months calculated as (numYears * 12) + numMonths.
     * @dev The calculation is performed in an unchecked block to avoid overflow checks, assuming the inputs are valid.
     */
    function _totalMonths(uint256 numYears, uint256 numMonths)
        private
        pure
        returns (uint256 total)
    {
        unchecked {
            total = numYears * 12 + numMonths - 1;
        }
    }

    /**
     * @notice A private pure function to add two unsigned integers.
     * @dev Uses unchecked block to prevent overflow checks, assuming the caller ensures valid inputs.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return c The sum of `a` and `b`.
     */
    function _add(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a + b;
        }
    }

    /**
     * @notice A private pure function to subtract two unsigned integers.
     * @dev Uses unchecked block to prevent overflow checks, assuming the caller ensures `a >= b`.
     * @param a The minuend (the number from which another number is to be subtracted).
     * @param b The subtrahend (the number to be subtracted).
     * @return c The result of the subtraction.
     */
    function _sub(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a - b;
        }
    }

    /**
     * @notice Calculates the timestamp for a given date and time, adjusted for the number of days in the month.
     *
     * Steps:
     * 1. Determine the number of days in the specified month and year.
     * 2. If the provided day exceeds the number of days in the month, set the day to the last day of the month.
     * 3. Convert the adjusted date to an epoch day (number of days since the Unix epoch).
     * 4. Multiply the epoch day by 86400 (seconds in a day) and add the remainder of the timestamp divided by 86400.
     * 5. Return the resulting timestamp.
     */
    function _offsetted(uint256 year, uint256 month, uint256 day, uint256 timestamp)
        private
        pure
        returns (uint256 result)
    {
        uint256 md = daysInMonth(year, month);
        if (day > md) {
            day = md;
        }
        unchecked {
            result = dateToEpochDay(year, month, day) * SECS_PER_DAY + (timestamp % SECS_PER_DAY);
        }
    }
}
