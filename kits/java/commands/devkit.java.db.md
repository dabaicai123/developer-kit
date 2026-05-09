---
description: Review database schema, queries, indexes, migrations, and MyBatis-Plus patterns. Delegates to devkit:java:db.
argument-hint: "[schema|migration|performance|mybatis-plus|security] [path]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Invoke the `devkit:java:db` agent. If a path is given, review that file/directory. If no path given, use `git diff` as scope. Pass the review type as focus if provided.