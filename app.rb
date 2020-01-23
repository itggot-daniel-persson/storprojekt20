require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

get('/') do 
    if session[:user_id] == nil
        session[:user_id] = 0
    end
    if session[:rank] == nil
        session[:rank] = 0
    end
    slim(:"ads/index")
end

get('/register') do 
    slim(:"users/new")
end

post("/register_new_user") do
    username = params[:username]
    password = params[:password]
    password_confirmation = params[:password_confirmation]
    existing_username = db.execute("SELECT username FROM Users WHERE username = ?", username)

    if !existing_username.empty?
        session[:registration_error] = "Username is taken"
        redirect("/")
    end

    if password != password_confirmation
        session[:registration_error] = "Password do not match"
        redirect("/")
    end
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO Users (username, password_digest, rank) VALUES (?, ?, ?)", username, password_digest, 0)
    session[:username] = username
    redirect("/register_success")
end