Seed Dump
========

Seed Dump is a Rails 4 and 5 plugin that adds a rake task named `db:seed:dump`.

It allows you to create seed data files from the existing data in your database.

You can also use Seed Dump from the Rails console. See below for usage examples.

Installation
------------

Add it to your Gemfile with:
```ruby
gem 'seed_dump', git: 'git://github.com/renuo/seed_dump', branch: 'master'
```

Documentation
-------------

This documentation is point to the develop branch of the repository.
For the documentation of the current release head to: https://github.com/renuo/seed_dump/blob/master/README.md.

Examples
--------

### Rake task

Dump all data directly to `db/seeds.rb`:
```sh
  $ rake db:seed:dump
```
Result:
```ruby
Product.create!([
  { category_id: 1, description: "Long Sleeve Shirt", name: "Long Sleeve Shirt" },
  { category_id: 3, description: "Plain White Tee Shirt", name: "Plain T-Shirt" }
])
User.create!([
  { password: "123456", username: "test_1" },
  { password: "234567", username: "test_2" }
])
```

Dump only data from the users table and dump a maximum of 1 record:
```sh
$ rake db:seed:dump MODELS=User LIMIT=1
```

Result:
```ruby
User.create!([
  { password: "123456", username: "test_1" }
])
```

Append to `db/seeds.rb` instead of overwriting it:
```sh
rake db:seed:dump APPEND=true
```

Use another output file instead of `db/seeds.rb`:
```sh
rake db:seed:dump FILE=db/seeds/users.rb
```

Exclude `name` and `age` from the dump:
```sh
rake db:seed:dump EXCLUDE=name,age
```

There are more options that can be set— see below for all of them.

### Console

Output a dump of all User records:
```ruby
irb(main):001:0> puts SeedDump.dump(User)
User.create!([
  { password: "123456", username: "test_1" },
  { password: "234567", username: "test_2" }
])
```

Write the dump to a file:
```ruby
irb(main):002:0> SeedDump.dump(User, file: 'db/seeds.rb')
```

Append the dump to a file:
```ruby
irb(main):003:0> SeedDump.dump(User, file: 'db/seeds.rb', append: true)
```

Exclude `name` and `age` from the dump:
```ruby
irb(main):004:0> SeedDump.dump(User, exclude: [:name, :age])
```

Options are specified as a Hash for the second argument.

In the console, any relation of ActiveRecord rows can be dumped (not individual objects though)
```ruby
irb(main):001:0> puts SeedDump.dump(User.where(is_admin: false))
User.create!([
  { password: "123456", username: "test_1", is_admin: false },
  { password: "234567", username: "test_2", is_admin: false }
])
```

Options
-------

| Option          | Values        | Usage                                                                                                                      | Default                         |
|-----------------|---------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| append          | [true, false] | Set if the data should be appended to the file or overwritten                                                              | false                           |
| batch_size      | [Integer]     | Number of records written to the file at once. Decrease if you are running out of memory, Increase if too slow             | 1000                            |
| limit           | [Integer]     | Limits the number of entries dumped into the seeds file                                                                    | no                              |
| file            | [Path]        | Sets the file path for the output seeds file                                                                               | 'db/seeds.rb'                   |
| exclude         | [Columns]     | Exclude multiple attributes from the dump                                                                                  | [:id, :created_at, :updated_at] |
| import          | [true, false] | Use the format for the [activerecord-import](https://github.com/zdennis/activerecord-import) gem                           | false                           |
| conditions      | []            | Dump only specific records to the seeds. Can be set in the console with (e.g. `SeedDump.dump(User.where(state: :active))`) | None                            |
| models          | [Models]      | List of models that should be dumped to the seeds                                                                          | All Models                      |
| models_excluded | [Models]      | List of modles that should be excluded from the seeds dump                                                                 | No Models excluded              |
| insert_all      | [true, false] | Set if the data should use insert_all instead of create! in the dump                                                       | false                           |
