const std = @import("std");

pub const DosDateTime = struct {
    time: u16,
    date: u16,
};

/// Convert a UTC timestamp to DOS date/time fields.
///
/// DOS date/time values carry no timezone information.  ZLI stores them in
/// UTC so archives are reproducible regardless of the build machine's local
/// timezone.
pub fn fromTimestamp(nanoseconds: i96) DosDateTime {
    const seconds_i = @divFloor(nanoseconds, std.time.ns_per_s);
    const seconds: u64 = if (seconds_i <= 0) 0 else @intCast(seconds_i);
    const epoch_seconds: std.time.epoch.EpochSeconds = .{ .secs = seconds };
    const year_day = epoch_seconds.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch_seconds.getDaySeconds();

    return encode(
        year_day.year,
        month_day.month.numeric(),
        @as(u16, month_day.day_index) + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    );
}

pub fn now(io: std.Io) DosDateTime {
    return fromTimestamp(std.Io.Timestamp.now(io, .real).nanoseconds);
}

fn encode(year: u16, month: u16, day: u16, hour: u16, minute: u16, second: u16) DosDateTime {
    const dos_year: u16 = if (year < 1980) 0 else @min(year - 1980, 127);
    return .{
        .time = (hour << 11) | (minute << 5) | (second / 2),
        .date = (dos_year << 9) | (month << 5) | day,
    };
}
