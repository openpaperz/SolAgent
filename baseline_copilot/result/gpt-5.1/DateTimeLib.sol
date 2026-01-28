// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title DateTimeLib - Date and time utility library for Unix timestamps.
library DateTimeLib {
    uint256 internal constant SECONDS_PER_MINUTE = 60;
    uint256 internal constant SECONDS_PER_HOUR = 60 * 60;
    uint256 internal constant SECONDS_PER_DAY = 24 * 60 * 60;

    // Weekday constants where 1 = Monday, ..., 7 = Sunday.
    uint256 internal constant MON = 1;
    uint256 internal constant TUE = 2;
    uint256 internal constant WED = 3;
    uint256 internal constant THU = 4;
    uint256 internal constant FRI = 5;
    uint256 internal constant SAT = 6;
    uint256 internal constant SUN = 7;

    // Maximum supported year and derived constants.
    uint256 internal constant MAX_SUPPORTED_YEAR = 9999;

    // Precomputed max supported epoch day for 9999-12-31.
    // Computed via the same algorithm as dateToEpochDay.
    uint256 internal constant MAX_SUPPORTED_EPOCH_DAY = 2932896;

    // Max supported timestamp = MAX_SUPPORTED_EPOCH_DAY * SECONDS_PER_DAY + (SECONDS_PER_DAY - 1)
    uint256 internal constant MAX_SUPPORTED_TIMESTAMP =
        MAX_SUPPORTED_EPOCH_DAY * SECONDS_PER_DAY + (SECONDS_PER_DAY - 1);

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
            // Using the algorithm from Howard Hinnant, adapted for Solidity:
            // y -= m <= 2
            // const uint256 EPOCH_OFFSET = 719468;
            let y := year
            let m := month
            let d := day

            let m_le_2 := lt(m, 3)
            y := sub(y, m_le_2)

            // era = y / 400
            let era := div(y, 400)

            // yoe = y - era * 400
            let yoe := sub(y, mul(era, 400))

            // doy = (153*(m + (m > 2 ? -3 : 9)) + 2)/5 + d - 1
            // Compute month prime mp = m + (m > 2 ? -3 : 9)
            // if m > 2 then mp = m - 3 else mp = m + 9
            let gt2 := gt(m, 2)
            let mp := add(m, sub(mul(gt2, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 9))
            // (Note: 0xffff...ffff == -1 in two's complement. So m + (-1 * gt2 - 9) = m-3 when gt2, else m-9.)

            // 153*mp + 2
            let tmp := add(mul(153, mp), 2)

            // (153*mp + 2) / 5
            let divv := div(tmp, 5)

            let doy := add(sub(divv, 1), d)

            // doe = yoe*365 + yoe/4 - yoe/100 + doy
            let doe := add(
                add(
                    add(mul(365, yoe), div(yoe, 4)),
                    sub(0, div(yoe, 100))
                ),
                doy
            )

            // epochDay = era*146097 + doe - 719468
            epochDay := sub(add(mul(era, 146097), doe), 719468)
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
            // Based on Howard Hinnant's algorithm.
            // z = epochDay + 719468
            let z := add(epochDay, 719468)

            // era = z / 146097
            let era := div(z, 146097)

            // doe = z - era * 146097
            let doe := sub(z, mul(era, 146097))

            // yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
            let doeDiv1460 := div(doe, 1460)
            let doeDiv36524 := div(doe, 36524)
            let doeDiv146096 := div(doe, 146096)

            let yoe := div(
                add(
                    sub(doe, doeDiv1460),
                    sub(doeDiv36524, doeDiv146096)
                ),
                365
            )

            // doy = doe - (365*yoe + yoe/4 - yoe/100)
            let tmp := add(
                mul(365, yoe),
                sub(div(yoe, 4), div(yoe, 100))
            )
            let doy := sub(doe, tmp)

            // mp = (5*doy + 2) / 153
            let mp := div(add(mul(5, doy), 2), 153)

            // day = doy - (153*mp + 2)/5 + 1
            day := add(
                sub(
                    doy,
                    div(add(mul(153, mp), 2), 5)
                ),
                1
            )

            // month = mp + 3 if mp < 10 else mp - 9
            switch lt(mp, 10)
            case 1 {
                month := add(mp, 3)
            }
            default {
                month := sub(mp, 9)
            }

            // year = yoe + era*400 if month > 2 else yoe + era*400 + 1
            let baseYear := add(yoe, mul(era, 400))
            switch gt(month, 2)
            case 1 {
                year := baseYear
            }
            default {
                year := add(baseYear, 1)
            }
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
            result = dateToEpochDay(year, month, day) * SECONDS_PER_DAY;
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
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (year, month, day) = epochDayToDate(epochDay_);
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
            uint256 epochDay_ = dateToEpochDay(year, month, day);
            result =
                epochDay_ *
                SECONDS_PER_DAY +
                hour *
                SECONDS_PER_HOUR +
                minute *
                SECONDS_PER_MINUTE +
                second;
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
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (year, month, day) = epochDayToDate(epochDay_);

        uint256 secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
        secs %= SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
        second = secs % SECONDS_PER_MINUTE;
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
            // leap if (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
            let y4 := iszero(mod(year, 4))
            let y100 := iszero(mod(year, 100))
            let y400 := iszero(mod(year, 400))
            leap := and(y4, or(iszero(y100), y400))
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
    function daysInMonth(uint256 year, uint256 month)
        internal
        pure
        returns (uint256 result)
    {
        bool leap = isLeapYear(year);
        assembly {
            // Days for months Jan..Dec in a packed 32-byte word (1 byte each):
            // 31,28,31,30,31,30,31,31,30,31,30,31
            // Packed LSB-first = 0x1f1e1f1e1f1f1e1f1e1f1c1f
            // We'll load from a constant via codecopy-like pattern using shift.
            let table :=
                0x001f1e1f1e1f1f1e1f1e1f1c1f0000000000000000000000000000000000000000

            // month is 1-12. We need (month-1)-th byte from LSB.
            let idx := sub(month, 1)
            let shiftBits := mul(idx, 8)
            result := and(shr(shiftBits, table), 0xff)

            // If leap year and February, add 1
            if and(leap, eq(month, 2)) {
                result := add(result, 1)
            }
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
    function weekday(uint256 timestamp)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            // 1970-01-01 is Thursday => day index 4 (Mon=1)
            result = ((timestamp / SECONDS_PER_DAY) + 3) % 7 + 1;
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
        uint256 dim = daysInMonth(year, month);
        assembly {
            result := 1
            // year >= 1970 && year <= MAX_SUPPORTED_YEAR
            if or(lt(year, 1970), gt(year, MAX_SUPPORTED_YEAR)) {
                result := 0
            }
            // 1 <= month <= 12
            if or(lt(month, 1), gt(month, 12)) {
                result := 0
            }
            // 1 <= day <= dim
            if or(lt(day, 1), gt(day, dim)) {
                result := 0
            }
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
        if (!isSupportedDate(year, month, day)) {
            return false;
        }
        assembly {
            result := 1
            if or(or(gt(hour, 23), gt(minute, 59)), gt(second, 59)) {
                result := 0
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
     * 2. Compare the provided `epochDay` with the maximum supported epoch day (`MAX_SUPPORTED_EPOCH_DAY`.
     * 3. Return `true` if the `epochDay` is less than or equal to `MAX_SUPPORTED_EPOCH_DAY`, otherwise return `false`.
     */
    function isSupportedEpochDay(uint256 epochDay)
        internal
        pure
        returns (bool result)
    {
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
    function isSupportedTimestamp(uint256 timestamp)
        internal
        pure
        returns (bool result)
    {
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
    function nthWeekdayInMonthOfYearTimestamp(
        uint256 year,
        uint256 month,
        uint256 n,
        uint256 wd
    ) internal pure returns (uint256 result) {
        uint256 firstEpochDay = dateToEpochDay(year, month, 1);
        uint256 dim = daysInMonth(year, month);

        assembly {
            // Weekday for first day of month, 0 = Sunday .. 6 = Saturday.
            // Our weekday() returns 1..7 (Mon..Sun).
            // Convert: wdFirst = (weekday(firstTimestamp) + 6) % 7
            let firstTs := mul(firstEpochDay, SECONDS_PER_DAY)
            let wdFirst := add(div(firstTs, SECONDS_PER_DAY), 3)
            wdFirst := add(mod(wdFirst, 7), 1)
            wdFirst := mod(add(wdFirst, 6), 7)

            // Compute offset to first desired weekday
            // delta = (wd + 7 - wdFirst) % 7
            let delta := mod(add(add(wd, 7), sub(0, wdFirst)), 7)

            // Day of month for nth weekday
            // dayOfMonth = 1 + delta + 7*(n-1)
            let dom := add(add(1, delta), mul(7, sub(n, 1)))

            // If dayOfMonth > dim, result = 0
            if gt(dom, dim) {
                result := 0
            }
            if iszero(gt(dom, dim)) {
                result := mul(add(firstEpochDay, sub(dom, 1)), SECONDS_PER_DAY)
            }
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
    function mondayTimestamp(uint256 timestamp)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            // If timestamp < 4 days since epoch, return 0 to avoid underflow
            if lt(timestamp, 345600) {
                result := 0
            }
            if iszero(lt(timestamp, 345600)) {
                let daysSince := div(timestamp, SECONDS_PER_DAY)
                // weekday index (0=Monday..6=Sunday)
                let w := mod(add(daysSince, 3), 7)
                let mondayDays := sub(daysSince, w)
                result := mul(mondayDays, SECONDS_PER_DAY)
            }
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
    function isWeekEnd(uint256 timestamp)
        internal
        pure
        returns (bool result)
    {
        uint256 wd_ = weekday(timestamp);
        result = wd_ > FRI;
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
    function addYears(uint256 timestamp, uint256 numYears)
        internal
        pure
        returns (uint256 result)
    {
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(epochDay_);
        year = _add(year, numYears);
        result = _offsetted(year, month, day, timestamp);
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
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(epochDay_);

        unchecked {
            uint256 total = _totalMonths(year, month - 1);
            total = _add(total, numMonths);

            year = total / 12;
            month = (total % 12) + 1;
        }

        result = _offsetted(year, month, day, timestamp);
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
    function addDays(uint256 timestamp, uint256 numDays)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp + numDays * SECONDS_PER_DAY;
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
    function addHours(uint256 timestamp, uint256 numHours)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp + numHours * SECONDS_PER_HOUR;
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
            result = timestamp + numMinutes * SECONDS_PER_MINUTE;
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
    function subYears(uint256 timestamp, uint256 numYears)
        internal
        pure
        returns (uint256 result)
    {
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(epochDay_);
        year = _sub(year, numYears);
        result = _offsetted(year, month, day, timestamp);
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
        uint256 epochDay_ = timestamp / SECONDS_PER_DAY;
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(epochDay_);
        unchecked {
            uint256 total = _totalMonths(year, month - 1);
            total = _sub(total, numMonths);

            year = total / 12;
            month = (total % 12) + 1;
        }
        result = _offsetted(year, month, day, timestamp);
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
    function subDays(uint256 timestamp, uint256 numDays)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp - numDays * SECONDS_PER_DAY;
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
    function subHours(uint256 timestamp, uint256 numHours)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = timestamp - numHours * SECONDS_PER_HOUR;
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
            result = timestamp - numMinutes * SECONDS_PER_MINUTE;
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
        uint256 fromEpoch = fromTimestamp / SECONDS_PER_DAY;
        uint256 toEpoch = toTimestamp / SECONDS_PER_DAY;

        (uint256 fromYear,,) = epochDayToDate(fromEpoch);
        (uint256 toYear,,) = epochDayToDate(toEpoch);

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
        uint256 fromEpoch = fromTimestamp / SECONDS_PER_DAY;
        uint256 toEpoch = toTimestamp / SECONDS_PER_DAY;

        (uint256 fromYear, uint256 fromMonth,) = epochDayToDate(fromEpoch);
        (uint256 toYear, uint256 toMonth,) = epochDayToDate(toEpoch);

        uint256 fromTotal = _totalMonths(fromYear, fromMonth - 1);
        uint256 toTotal = _totalMonths(toYear, toMonth - 1);
        result = _sub(toTotal, fromTotal);
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
            result = (toTimestamp - fromTimestamp) / SECONDS_PER_DAY;
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
            result = (toTimestamp - fromTimestamp) / SECONDS_PER_HOUR;
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
            result = (toTimestamp - fromTimestamp) / SECONDS_PER_MINUTE;
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
            total = numYears * 12 + numMonths;
        }
    }

    /**
     * @notice A private pure function to add two unsigned integers.
     * @dev Uses unchecked block to prevent overflow checks, assuming the caller ensures valid inputs.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @return c The sum of `a` and `b`.
     */
    function _add(uint256 a, uint256 b)
        private
        pure
        returns (uint256 c)
    {
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
    function _sub(uint256 a, uint256 b)
        private
        pure
        returns (uint256 c)
    {
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
    function _offsetted(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 timestamp
    ) private pure returns (uint256 result) {
        uint256 dim = daysInMonth(year, month);
        if (day > dim) {
            day = dim;
        }
        uint256 epochDay_ = dateToEpochDay(year, month, day);
        unchecked {
            result = epochDay_ * SECONDS_PER_DAY + (timestamp % SECONDS_PER_DAY);
        }
    }
}