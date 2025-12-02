# Open GitHub Issues Summary

Generated: 2025-12-01 | Total: 32 open issues

## Recently Fixed

### [#111](https://github.com/rroblak/seed_dump/issues/111) - DateTime timezone issues - **Fixed in d3259ba**
### [#154](https://github.com/rroblak/seed_dump/issues/154) - ActionText::RichText not working - **Fixed in 8b3fbb8**
### [#165](https://github.com/rroblak/seed_dump/issues/165) - PostgreSQL COUNT with multiple arguments - **Fixed in f830703**
### [#167](https://github.com/rroblak/seed_dump/issues/167) - Dangerous query method - **Fixed in d30cc0f**
### [#138](https://github.com/rroblak/seed_dump/issues/138) - Duplicated records issue - **Fixed in d30cc0f**
### [#123](https://github.com/rroblak/seed_dump/issues/123) - Duplicate records dumped - **Fixed in d30cc0f**
### [#130](https://github.com/rroblak/seed_dump/issues/130) - HABTM import fails - **Fixed**
### [#105](https://github.com/rroblak/seed_dump/issues/105) - Hashes in text fields not dumped correctly - **Fixed in db880b1**
### [#84](https://github.com/rroblak/seed_dump/issues/84) - BigDecimal causes syntax errors - **Fixed in db880b1**

---

## High Priority
Bugs causing incorrect output or significant usability issues.

### [#112](https://github.com/rroblak/seed_dump/issues/112) - NoMethodError: undefined method 'exists?' (2016-08-22)
Error when running `rake db:seed:dump` without MODEL specified. `ActiveRecord::Base.descendants` may include non-model classes.

---

## Medium Priority
Feature requests and compatibility issues.

### [#153](https://github.com/rroblak/seed_dump/issues/153) - Support insert_all (2021-03-08)
Feature request to add `insert_all` output format for faster bulk inserts (Rails 6+).

### [#150](https://github.com/rroblak/seed_dump/issues/150) - /dev/stdout doesn't work with pipes (2020-07-31)
File opened in `w+` mode fails when stdout is redirected. Should use `w` mode instead.

### [#147](https://github.com/rroblak/seed_dump/issues/147) - Awkward way to remove default excludes (2020-06-04)
No clean way to include `id`, `created_at`, `updated_at`. Currently requires `EXCLUDE=""` hack.

### [#142](https://github.com/rroblak/seed_dump/issues/142) - LIMIT breaks associations (2019-02-27)
Using LIMIT=10 on associated models causes incomplete/broken relationships (e.g., Teacher has 100 students but only 10 dumped).

### [#136](https://github.com/rroblak/seed_dump/issues/136) - Support Sequel ORM (2018-09-24)
Feature request to support Sequel ORM in addition to ActiveRecord.

### [#128](https://github.com/rroblak/seed_dump/issues/128) - Exclude created_on/updated_on (2017-08-15)
Rails also supports `created_on` and `updated_on` timestamp columns, which should be excluded by default.

### [#127](https://github.com/rroblak/seed_dump/issues/127) - BATCH_SIZE option not working (2017-06-09)
BATCH_SIZE parameter appears to have no effect on output format.

### [#121](https://github.com/rroblak/seed_dump/issues/121) - Model name ending in 's' bug (2017-02-14)
Model "Boss" requires `MODELS=Bosss` (extra 's') due to singularize/pluralize logic.

### [#120](https://github.com/rroblak/seed_dump/issues/120) - STI creates duplicate tables (2017-02-12)
With STI (User, Author < User, Publisher < User), all three are dumped separately instead of just the base table.

### [#117](https://github.com/rroblak/seed_dump/issues/117) - CarrierWave columns dump as nil (2016-11-19)
CarrierWave uploader columns always dump to nil instead of the stored filename.

### [#114](https://github.com/rroblak/seed_dump/issues/114) - Rolify gem duplicates (2016-08-31)
`Role::HABTM_Users` and `User::HABTM_Roles` both created, duplicating role assignments.

### [#104](https://github.com/rroblak/seed_dump/issues/104) - Non-continuous IDs break foreign keys (2016-06-07)
When rows are deleted from parent table, foreign key references become incorrect on reimport.

### [#83](https://github.com/rroblak/seed_dump/issues/83) - Foreign key ordering (2015-06-17)
Records with foreign keys may be emitted before their referenced records, causing import failures.

### [#78](https://github.com/rroblak/seed_dump/issues/78) - Alphabetical order breaks validations (2015-04-13)
Models dumped alphabetically (Games, Ratings, Users) but Ratings need Users/Games first.

### [#26](https://github.com/rroblak/seed_dump/issues/26) - HABTM join table support (2013-05-13)
Request for dumping join tables from `has_and_belongs_to_many` associations.

---

## Low Priority
Documentation, edge cases, and nice-to-haves.

### [#155](https://github.com/rroblak/seed_dump/issues/155) - Contact request (2021-09-23)
User asking how to contact maintainer. Not a technical issue.

### [#152](https://github.com/rroblak/seed_dump/issues/152) - How to include ID in dump (2020-11-25)
User asking how to dump ID column. Answer: use `EXCLUDE=created_at,updated_at` (omit id).

### [#146](https://github.com/rroblak/seed_dump/issues/146) - Document standalone-migrations usage (2020-02-12)
Documentation request: how to use seed_dump outside of Rails with standalone-migrations.

### [#139](https://github.com/rroblak/seed_dump/issues/139) - Windows error (2018-12-10)
`{#: command not found` on Windows. Likely shell/environment issue, not gem bug.

### [#137](https://github.com/rroblak/seed_dump/issues/137) - Only one model dumped (2018-10-09)
User reports only Alchemy::User dumped. Likely user error or caching issue.

### [#126](https://github.com/rroblak/seed_dump/issues/126) - Add comment header to seed file (2017-05-25)
Feature request: add comment showing seed_dump was used and which options.

### [#100](https://github.com/rroblak/seed_dump/issues/100) - Tables vs Models confusion (2016-04-24)
User confusion about MODELS param with STI. Suggests adding TABLES param.

### [#98](https://github.com/rroblak/seed_dump/issues/98) - Missing models when dumping (2016-04-07)
Refinery::ImagePage not dumped automatically. Worked with explicit MODEL param.

### [#97](https://github.com/rroblak/seed_dump/issues/97) - Association support question (2016-04-04)
User asking if associations are supported. Feature request for smarter associated record dumping.

### [#85](https://github.com/rroblak/seed_dump/issues/85) - PG_SCHEMA option removed (2015-07-13)
Question about why PG_SCHEMA was removed post-v1.0.0.

---

## Summary by Priority

| Priority | Count | Key Issues |
|----------|-------|------------|
| Critical | 0 | - |
| High | 4 | HABTM, BigDecimal, hashes serialization |
| Medium | 15 | insert_all, STI, foreign keys, CarrierWave |
| Low | 10 | Documentation, user questions, edge cases |
