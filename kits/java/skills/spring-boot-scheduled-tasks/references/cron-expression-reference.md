# Cron Expression Reference

## Cron expression format

### Spring (6 fields)

Spring `@Scheduled` cron uses 6 fields:

```
┌───────────── seconds (0-59)
│ ┌───────────── minutes (0-59)
│ │ ┌───────────── hours (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12 or JAN-DEC)
│ │ │ │ │ ┌───────────── day of week (0-7 or MON-SUN)
│ │ │ │ │ │
* * * * * *
```

### Quartz / XXL-Job (7 fields)

XXL-Job and Quartz use 7 fields — the same as Spring cron plus an optional year field at the end:

```
┌───────────── seconds (0-59)
│ ┌───────────── minutes (0-59)
│ │ ┌───────────── hours (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12 or JAN-DEC)
│ │ │ │ │ ┌───────────── day of week (1-7 or MON-SUN)
│ │ │ │ │ │ ┌───────────── year (optional, 1970-2099)
│ │ │ │ │ │ │
* * * * * * *
```

**Important differences:**
- Both start with seconds field
- Spring: 0 and 7 both = Sunday. Quartz: 1 = Sunday, 7 = Saturday
- Quartz/XXL-Job has optional 7th field for year; Spring does NOT support year

## Field order and valid ranges

| Field | Position | Range | Allowed Values |
|-------|----------|-------|----------------|
| Seconds | 1 | 0-59 | 0, 5, 10, 0/5, etc. |
| Minutes | 2 | 0-59 | 0, 15, 30, 0/15, etc. |
| Hours | 3 | 0-23 | 0, 6, 9, 12, etc. |
| Day of month | 4 | 1-31 | 1, 15, L, 15W, etc. |
| Month | 5 | 1-12 or JAN-DEC | 1, JAN, JAN-MAR, etc. |
| Day of week | 6 | 0-7 or MON-SUN (Spring) / 1-7 (Quartz) | MON, MON-FRI, 6L, etc. |
| Year (Quartz only) | 7 | 1970-2099 | 2026, 2026-2030, etc. |

## Special characters

| Character | Name | Description | Example |
|-----------|------|-------------|---------|
| `*` | Any | Matches any value in the field range | `* * * * * ?` = every second |
| `?` | No specific value | Used in day-of-month or day-of-week when you don't care about one of them. One of these two fields MUST use `?` | `0 0 12 * * ?` = noon every day (day-of-week is "?") |
| `-` | Range | Specifies a range of values | `0 0 9-17 * * ?` = every hour from 9am to 5pm |
| `,` | List | Specifies multiple values | `0 0 9,12,18 * * ?` = at 9am, noon, 6pm |
| `/` | Step | Specifies increments. `start/step` means start at `start`, then every `step` | `0 0/5 * * * ?` = every 5 minutes starting at minute 0 |
| `L` | Last | Last day of month or last day of week | `0 0 0 L * ?` = last day of month at midnight |
| `W` | Weekday | Nearest weekday (Mon-Fri) to the given day | `0 0 0 15W * ?` = nearest weekday to the 15th |
| `#` | Nth day | Nth occurrence of a given day-of-week in the month | `0 0 0 ? * 6#3` = 3rd Friday of the month |

**Rules for `?`:**
- NOT set both day-of-month and day-of-week to specific values in Quartz/XXL-Job — one MUST use `?`
- Spring allows `*` + specific values together, but `?` is clearer practice
- Example: `0 0 12 ? * MON-FRI` = noon on weekdays (day-of-month is `?`)

## Common cron expressions table

### Every N seconds/minutes/hours

| Expression | Description | Spring | XXL-Job |
|-----------|-------------|--------|---------|
| `* * * * * ?` | Every second | Yes | Yes |
| `0 * * * * ?` | Every minute | Yes | Yes |
| `0 0 * * * ?` | Every hour | Yes | Yes |
| `0 0/5 * * * ?` | Every 5 minutes | Yes | Yes |
| `0 0/10 * * * ?` | Every 10 minutes | Yes | Yes |
| `0 0/30 * * * ?` | Every 30 minutes | Yes | Yes |
| `0 0 0/2 * * ?` | Every 2 hours | Yes | Yes |

### Specific times

| Expression | Description | Spring | XXL-Job |
|-----------|-------------|--------|---------|
| `0 0 9 * * ?` | Daily at 9:00 AM | Yes | Yes |
| `0 30 9 * * ?` | Daily at 9:30 AM | Yes | Yes |
| `0 0 9,18 * * ?` | Daily at 9:00 AM and 6:00 PM | Yes | Yes |
| `0 0 9-17 * * ?` | Every hour from 9 AM to 5 PM | Yes | Yes |
| `0 0 12 ? * MON-FRI` | Weekdays at noon | Yes | Yes (use ? in day-of-month) |
| `0 0 9 ? * MON-FRI` | Weekdays at 9:00 AM | Yes | Yes |

### Monthly / yearly patterns

| Expression | Description | Spring | XXL-Job |
|-----------|-------------|--------|---------|
| `0 0 0 1 * ?` | Monthly on the 1st at midnight | Yes | Yes |
| `0 0 9 1,15 * ?` | On the 1st and 15th at 9 AM | Yes | Yes |
| `0 0 0 L * ?` | Last day of month at midnight | Yes | Yes |
| `0 0 0 ? * 6#3` | 3rd Friday of month at midnight | Yes | Yes (note: Quartz uses different weekday numbering) |
| `0 0 9 1 JAN ?` | January 1st at 9 AM | Yes | Yes |

### Common business patterns

| Expression | Description |
|-----------|-------------|
| `0 0/1 * * * ?` | Every 1 minute — heartbeat, status check |
| `0 0/5 * * * ?` | Every 5 minutes — metrics collection |
| `0 0/10 * * * ?` | Every 10 minutes — data sync |
| `0 0 2 * * ?` | Daily at 2:00 AM — nightly batch processing |
| `0 0 3 * * ?` | Daily at 3:00 AM — data cleanup |
| `0 30 0 * * ?` | Daily at 0:30 AM — report generation |
| `0 0 9 ? * MON-FRI` | Weekdays at 9:00 AM — daily report |
| `0 0 0 1 * ?` | Monthly on 1st at midnight — monthly settlement |
| `0 0 10 1,15 * ?` | On 1st and 15th at 10:00 AM — payroll processing |
| `0 0 2 L * ?` | Last day of month at 2:00 AM — month-end closing |

## Spring vs Quartz format differences

| Feature | Spring | Quartz / XXL-Job |
|---------|--------|-------------------|
| Fields | 6 (seconds–day-of-week) | 7 (seconds–year, year optional) |
| Year field | NOT supported | Optional 7th field |
| Day-of-week | 0/7 = Sunday, 1 = Monday | 1 = Sunday, 7 = Saturday |
| `L` | Supported | Same |
| `W` | Supported | Same |
| `#` | Supported | Same |
| `?` requirement | Recommended, not mandatory | Must use `?` in one day field when other is specified |

## XXL-Job cron format (uses Quartz 7-field format)

XXL-Job uses the Quartz 7-field cron format. When configuring tasks in the XXL-Job admin console, use 7-field expressions:

```
Seconds  Minutes  Hours  DayOfMonth  Month  DayOfWeek  Year
0        0        9      ?           *      MON-FRI    (year omitted = every year)
```

If you omit the year field, it defaults to every year (equivalent to `*`).

Examples in XXL-Job admin console:
- `0 0/5 * * * ?` — every 5 minutes
- `0 0 2 * * ?` — daily at 2:00 AM
- `0 0 9 ? * MON-FRI` — weekdays at 9:00 AM
- `0 0 0 1 * ? 2026` — on the 1st of each month in 2026 only

## Converting between Spring and Quartz formats

Most common cron expressions are identical between Spring and Quartz/XXL-Job — the only difference is the optional year field at the end.

**Spring cron in `@Scheduled`:**
```java
@Scheduled(cron = "0 0 9 ? * MON-FRI")  // 6 fields
public void dailyReport() { ... }
```

**Same expression in XXL-Job admin console:**
```
0 0 9 ? * MON-FRI    // 6 fields — year field omitted, same effect
```

**With year field in XXL-Job:**
```
0 0 9 ? * MON-FRI 2026    // 7 fields — only in 2026
```

**Day-of-week numbering difference:**
- Spring: `0 0 9 ? * 0` = Sunday at 9 AM (0 and 7 both = Sunday, 1 = Monday)
- Quartz/XXL-Job: `0 0 9 ? * 1` = Sunday at 9 AM (1 = Sunday in Quartz convention)
- NOT mix numeric weekday values between Spring and Quartz — use named weekdays (MON-FRI) to avoid confusion