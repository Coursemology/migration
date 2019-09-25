Archived as migration is complete

# Coursemogy Migration
Migration script from Coursemology v1 to v2.

## Usage
Add these line to the application's Gemfile:

```ruby
gem 'mysql2'
gem 'redis'
```

Add a new connection to the old database in `database.yml`.
```yaml
v1:
  adapter: mysql2
  database: coursemology
  host: coursemology.org
```

Clone the files from this repo to Coursemology V2's `lib/tasks` directory.

And then:
```sh
$ rake migration:start
```
