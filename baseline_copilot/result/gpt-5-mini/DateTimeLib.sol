// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library DateTimeLib {
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant SECONDS_PER_HOUR = 3600;
    uint256 private constant SECONDS_PER_MINUTE = 60;
    uint256 private constant DAYS_PER_400_YEARS = 146097; // 365*400 + 97
    uint256 private constant EPOCH_DAY_OFFSET = 719468; // days from civil algorithm offset

    /// @notice Converts a given date (year, month, day) into the number of days since the Unix epoch (January 1, 1970).
    function dateToEpochDay(uint256 year, uint256 month, uint256 day) internal pure returns (uint256 epochDay) {
        // Based on Howard Hinnant's days_from_civil algorithm
        unchecked {
            uint256 y = year;
            uint256 m = month;
            // If month <= 2, treat as month + 12 and year - 1
            if (m <= 2) {
                y -= 1;
                m += 12;
            }
            // era = floor(y / 400)
            uint256 era = y / 400;
            uint256 yoe = y - era * 400; // [0, 399]
            uint256 doy = (153 * (m - 3) + 2) / 5 + day - 1; // [0, 365]
            uint256 doe = yoe * 365 + yoe / 4 - yoe / 100 + doy; // [0, 146096]
            uint256 days = era * DAYS_PER_400_YEARS + doe;
            // convert to epoch days by subtracting offset
            epochDay = days - EPOCH_DAY_OFFSET;
        }
    }

    /// @notice Converts a given epoch day (days since 1970-01-01) to a date in the format of year, month, and day.
    function epochDayToDate(uint256 epochDay) internal pure returns (uint256 year, uint256 month, uint256 day) {
        unchecked {
            uint256 z = epochDay + EPOCH_DAY_OFFSET;
            uint256 era = z / DAYS_PER_400_YEARS;
            uint256 doe = z - era * DAYS_PER_400_YEARS; // [0, 146096]
            uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; // [0, 399]
            uint256 y = yoe + era * 400;
            uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
            uint256 mp = (5 * doy + 2) / 153; // [0, 11]
            uint256 d = doy - (153 * mp + 2) / 5 + 1; // [1, 31]
            uint256 m = mp + 3;
            if (m > 12) {
                m -= 12;
                y += 1;
            }
            year = y;
            month = m;
            day = d;
        }
    }

    /// @notice Converts a given date (year, month, day) into a Unix timestamp.
    function dateToTimestamp(uint256 year, uint256 month, uint256 day) internal pure returns (uint256 result) {
        unchecked {
            uint256 epochDay = dateToEpochDay(year, month, day);
            result = epochDay * SECONDS_PER_DAY;
        }
    }

    /// @notice Converts a Unix timestamp to a date (year, month, day).
    function timestampToDate(uint256 timestamp) internal pure returns (uint256 year, uint256 month, uint256 day) {
        unchecked {
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (year, month, day) = epochDayToDate(epochDay);
        }
    }

    /// @notice Converts a given date and time into a Unix timestamp.
    function dateTimeToTimestamp(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (uint256 result) {
        unchecked {
            result = dateToTimestamp(year, month, day);
            result += hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
        }
    }

    /// @notice Converts a Unix timestamp into a human-readable date and time format.
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
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (year, month, day) = epochDayToDate(epochDay);
            uint256 secs = timestamp % SECONDS_PER_DAY;
            hour = secs / SECONDS_PER_HOUR;
            secs = secs % SECONDS_PER_HOUR;
            minute = secs / SECONDS_PER_MINUTE;
            second = secs % SECONDS_PER_MINUTE;
        }
    }

    /// @notice Determines if a given year is a leap year.
    function isLeapYear(uint256 year) internal pure returns (bool leap) {
        // Leap year if divisible by 4 and not by 100 unless divisible by 400
        leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }

    /// @notice Calculates the number of days in a given month and year, taking leap years into account.
    function daysInMonth(uint256 year, uint256 month) internal pure returns (uint256 result) {
        require(month >= 1 && month <= 12, "Invalid month");
        unchecked {
            if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
                result = 31;
            } else if (month == 4 || month == 6 || month == 9 || month == 11) {
                result = 30;
            } else {
                // February
                result = isLeapYear(year) ? 29 : 28;
            }
        }
    }

    /// @notice Calculates the day of the week (1-7) for a given Unix timestamp.
    /// @return result The day of the week, where 1 = Monday, ..., 7 = Sunday.
    function weekday(uint256 timestamp) internal pure returns (uint256 result) {
        unchecked {
            uint256 daysSinceEpoch = timestamp / SECONDS_PER_DAY;
            // Jan 1, 1970 was a Thursday; adding 3 aligns Monday as 1
            result = (daysSinceEpoch + 3) % 7 + 1;
        }
    }

    /// @notice Checks if the provided date (year, month, day) is supported by the system.
    function isSupportedDate(uint256 year, uint256 month, uint256 day) internal pure returns (bool result) {
        unchecked {
            if (year < 1970) return false;
            if (month < 1 || month > 12) return false;
            uint256 dim = daysInMonth(year, month);
            if (day < 1 || day > dim) return false;
            result = true;
        }
    }

    /// @notice Checks if the provided date and time values are supported.
    function isSupportedDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (bool result) {
        unchecked {
            if (!isSupportedDate(year, month, day)) return false;
            if (hour >= 24) return false;
            if (minute >= 60) return false;
            if (second >= 60) return false;
            result = true;
        }
    }

    /// @notice Checks if the provided epoch day is within the supported range.
    function isSupportedEpochDay(uint256 epochDay) internal pure returns (bool result) {
        unchecked {
            // We allow a very large epoch day; practically limited by uint256
            // But maintain a sane upper bound equivalent to year 9999 end
            // epoch day for 9999-12-31 approximated ~ 3652058
            uint256 MAX_SUPPORTED_EPOCH_DAY = 3652058;
            result = epochDay <= MAX_SUPPORTED_EPOCH_DAY;
        }
    }

    /// @notice Checks if a given timestamp is within the supported range.
    function isSupportedTimestamp(uint256 timestamp) internal pure returns (bool result) {
        unchecked {
            uint256 MAX_SUPPORTED_TIMESTAMP = 3652058 * SECONDS_PER_DAY;
            result = timestamp <= MAX_SUPPORTED_TIMESTAMP;
        }
    }

    /// @notice Calculates the Unix timestamp for the nth occurrence of a specific weekday in a given month and year.
    function nthWeekdayInMonthOfYearTimestamp(
        uint256 year,
        uint256 month,
        uint256 n,
        uint256 wd
    ) internal pure returns (uint256 result) {
        unchecked {
            if (n == 0 || wd > 6) return 0;
            // first day of month timestamp
            uint256 firstDayTs = dateToTimestamp(year, month, 1);
            uint256 firstWd = weekday(firstDayTs); // 1=Mon..7=Sun
            // convert to 0=Sun..6=Sat
            uint256 firstWd0 = firstWd % 7;
            uint256 diff = (wd + 7 - firstWd0) % 7;
            uint256 day = 1 + diff + (n - 1) * 7;
            uint256 dim = daysInMonth(year, month);
            if (day > dim) return 0;
            result = dateToTimestamp(year, month, day);
        }
    }

    /// @notice Calculates the timestamp of the most recent Monday at 00:00:00 UTC based on the given timestamp.
    function mondayTimestamp(uint256 timestamp) internal pure returns (uint256 result) {
        unchecked {
            if (timestamp <= 345599) {
                // handles edge cases (less than 4 days), return Monday of that week (could be epoch)
                uint256 daysSinceEpoch = timestamp / SECONDS_PER_DAY;
                uint256 w = (daysSinceEpoch + 3) % 7;
                uint256 mondayDay = daysSinceEpoch - w;
                result = mondayDay * SECONDS_PER_DAY;
            } else {
                uint256 daysSinceEpoch = timestamp / SECONDS_PER_DAY;
                uint256 w = (daysSinceEpoch + 3) % 7;
                uint256 mondayDay = daysSinceEpoch - w;
                result = mondayDay * SECONDS_PER_DAY;
            }
        }
    }

    /// @notice Checks if the given timestamp falls on a weekend.
    function isWeekEnd(uint256 timestamp) internal pure returns (bool result) {
        unchecked {
            uint256 wd = weekday(timestamp); // 1=Mon..7=Sun
            // Friday == 5, weekend are 6 (Sat) and 7 (Sun)
            result = wd > 5;
        }
    }

    /// @notice Adds a specified number of years to a given timestamp and returns the new timestamp.
    function addYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        unchecked {
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (uint256 y, uint256 m, uint256 d) = epochDayToDate(epochDay);
            y += numYears;
            result = _offsetted(y, m, d, timestamp);
        }
    }

    /// @notice Adds a specified number of months to a given timestamp and returns the resulting timestamp.
    function addMonths(uint256 timestamp, uint256 numMonths) internal pure returns (uint256 result) {
        unchecked {
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (uint256 y, uint256 m, uint256 d) = epochDayToDate(epochDay);
            uint256 total = _totalMonths(y, m - 1) + numMonths; // months since year 0, zero-based month
            uint256 newY = total / 12;
            uint256 newM = (total % 12) + 1;
            result = _offsetted(newY, newM, d, timestamp);
        }
    }

    /// @notice Adds a specified number of days to a given timestamp.
    function addDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numDays * SECONDS_PER_DAY;
        }
    }

    /// @notice Adds a specified number of hours to a given timestamp.
    function addHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numHours * SECONDS_PER_HOUR;
        }
    }

    /// @notice Adds a specified number of minutes to a given timestamp.
    function addMinutes(uint256 timestamp, uint256 numMinutes) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numMinutes * SECONDS_PER_MINUTE;
        }
    }

    /// @notice Adds a specified number of seconds to a given timestamp.
    function addSeconds(uint256 timestamp, uint256 numSeconds) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp + numSeconds;
        }
    }

    /// @notice Subtracts a specified number of years from a given timestamp and returns the resulting timestamp.
    function subYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        unchecked {
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (uint256 y, uint256 m, uint256 d) = epochDayToDate(epochDay);
            y -= numYears;
            result = _offsetted(y, m, d, timestamp);
        }
    }

    /// @notice Subtracts a specified number of months from a given timestamp.
    function subMonths(uint256 timestamp, uint256 numMonths) internal pure returns (uint256 result) {
        unchecked {
            uint256 epochDay = timestamp / SECONDS_PER_DAY;
            (uint256 y, uint256 m, uint256 d) = epochDayToDate(epochDay);
            uint256 total = _totalMonths(y, m - 1);
            uint256 newTotal = total - numMonths;
            uint256 newY = newTotal / 12;
            uint256 newM = (newTotal % 12) + 1;
            result = _offsetted(newY, newM, d, timestamp);
        }
    }

    /// @notice Subtracts a specified number of days from a given timestamp.
    function subDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numDays * SECONDS_PER_DAY;
        }
    }

    /// @notice Subtracts a specified number of hours from a given timestamp.
    function subHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numHours * SECONDS_PER_HOUR;
        }
    }

    /// @notice Subtracts a specified number of minutes from a given timestamp.
    function subMinutes(uint256 timestamp, uint256 numMinutes) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numMinutes * SECONDS_PER_MINUTE;
        }
    }

    /// @notice Subtracts a specified number of seconds from a given timestamp.
    function subSeconds(uint256 timestamp, uint256 numSeconds) internal pure returns (uint256 result) {
        unchecked {
            result = timestamp - numSeconds;
        }
    }

    /// @notice Calculates the difference in years between two timestamps.
    function diffYears(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            (uint256 y1, , ) = timestampToDate(fromTimestamp);
            (uint256 y2, , ) = timestampToDate(toTimestamp);
            result = _sub(y2, y1);
        }
    }

    /// @notice Calculates the difference in months between two timestamps.
    function diffMonths(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            (uint256 y1, uint256 m1, ) = timestampToDate(fromTimestamp);
            (uint256 y2, uint256 m2, ) = timestampToDate(toTimestamp);
            uint256 total1 = _totalMonths(y1, m1 - 1);
            uint256 total2 = _totalMonths(y2, m2 - 1);
            result = _sub(total2, total1);
        }
    }

    /// @notice Calculates the difference in days between two timestamps.
    function diffDays(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            result = _sub(toTimestamp, fromTimestamp) / SECONDS_PER_DAY;
        }
    }

    /// @notice Calculates the difference in hours between two timestamps.
    function diffHours(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            result = _sub(toTimestamp, fromTimestamp) / SECONDS_PER_HOUR;
        }
    }

    /// @notice Calculates the difference in minutes between two timestamps.
    function diffMinutes(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            result = _sub(toTimestamp, fromTimestamp) / SECONDS_PER_MINUTE;
        }
    }

    /// @notice Calculates the difference in seconds between two timestamps.
    function diffSeconds(uint256 fromTimestamp, uint256 toTimestamp) internal pure returns (uint256 result) {
        unchecked {
            result = _sub(toTimestamp, fromTimestamp);
        }
    }

    /// @notice Calculates the total number of months based on the given number of years and months.
    function _totalMonths(uint256 numYears, uint256 numMonths) private pure returns (uint256 total) {
        unchecked {
            total = numYears * 12 + numMonths;
        }
    }

    /// @notice A private pure function to add two unsigned integers.
    function _add(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a + b;
        }
    }

    /// @notice A private pure function to subtract two unsigned integers.
    function _sub(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a - b;
        }
    }

    /// @notice Calculates the timestamp for a given date and time, adjusted for the number of days in the month.
    function _offsetted(uint256 year, uint256 month, uint256 day, uint256 timestamp) private pure returns (uint256 result) {
        unchecked {
            uint256 dim = daysInMonth(year, month);
            uint256 d = day > dim ? dim : day;
            uint256 epochDay = dateToEpochDay(year, month, d);
            result = epochDay * SECONDS_PER_DAY + (timestamp % SECONDS_PER_DAY);
        }
    }
}