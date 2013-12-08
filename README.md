Seed Dump
========

Seed Dump is a Rails 4 plugin that adds a rake task named `db:seed:dump`.

It allows you to create seed data files from the existing data in your database.

You can also use Seed Dump from the Rails console.  See below for usage examples.

Note: if you want to use Seed Dump with Rails 3 or earlier, use [version 0.5.3](http://rubygems.org/gems/seed_dump/versions/0.5.3).

Installation
------------

Add it to your Gemfile with:

    gem 'seed_dump'

Or install it by hand:

    $ gem install seed_dump

Examples
--------

### Rake task

Dump all data directly to `db/seeds.rb`:

    $ rake db:seed:dump

Result:

    Product.create!([
      {category_id: 1, description: "Long Sleeve Shirt", name: "Long Sleeve Shirt"},
      {category_id: 3, description: "Plain White Tee Shirt", name: "Plain T-Shirt"}
    ])
    User.create!([
      {id: 1, password: "123456", username: "test_1"},
      {id: 2, password: "234567", username: "test_2"}
    ])

Dump only data from the users table and dump a maximum of 1 record:

    $ rake db:seed:dump MODELS=User,Product LIMIT=1

Result:

    User.create!([
      {id: 1, password: "123456", username: "test_1"}
    ])

Append to `db/seeds.rb` instead of overwriting it:

    rake db:seed:dump APPEND=true

Use another output file instead of `db/seeds.rb`:

    rake db:seed:dump FILE=db/seeds/users.rb

There are more options that can be set— see below for all of them.

### Console

Output a dump of all User records:

    irb(main):001:0> puts SeedDump.dump(User)
    User.create!([
      {id: 1, password: "123456", username: "test_1"},
      {id: 2, password: "234567", username: "test_2"}
    ])

Write the dump to a file:

    irb(main):002:0> SeedDump.dump(User, file: 'db/seeds.rb')

Append the dump to a file:

    irb(main):003:0> puts SeedDump.dump(User, file: 'db/seeds.rb', append: true)

Options are specified as a Hash to the second argument.

Options
-------

Options are common to both the Rake task and the console, except where noted.

`append`: If set to `true`, append the data to the file instead of overwriting it.  Default: `false`.

`batch_size`: Controls the number of records that are written to file at a given time.  Default: 1000.  If you're running out of memory when dumping, try decreasing this.  If things are dumping too slow, trying increasing this.

`exclude`: Attributes to be excluded from the dump.  Default: `id, created_at, updated_at`.

`file`: Write to the specified output file.  Default in Rake task is `db/seeds.rb`.  Console returns the dump as a string by default.

`limit`: Dump no more then this amount of data.  Default: no limit.  Rake task only.  In the console just pass in an ActiveRecord::Relation with the appropriate limit (e.g. `SeedDump.dump(User.limit(5))`).

`model[s]`: Restrict the dump to the specified comma-separated list of models.  Default: all models.  Rake task only.

