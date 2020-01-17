require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

