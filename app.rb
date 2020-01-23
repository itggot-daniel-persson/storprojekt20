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
    phone = params[:phone]
    email = params[:email]

    existing_username = db.execute("SELECT username FROM Users WHERE username = ?", username)
    existing_email = db.execute("SELECT email FROM Users WHERE email = ?", email)
    existing_phone = db.execute("SELECT phone FROM Users WHERE phone = ?", phone)

    if !existing_username.empty?
        session[:registration_error] = "Username is taken"
        redirect("/register")
    elsif password != password_confirmation
        session[:registration_error] = "Password do not match"
        redirect("/register")
    elsif !existing_email.empty?
        session[:registration_error] = "Email is taken"
        redirect("/register")
    elsif !existing_phone.empty?
        session[:registration_error] = "Phone is taken"
        redirect("/register")
    end
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO Users (username, password_digest, rank, email, phone) VALUES (?, ?, ?, ?, ?)", username, password_digest, "user", email, phone)
    session[:username] = username
    session[:user_id] = db.execute("SELECT user_id FROM users WHERE username = ?", session[:username])[0]["user_id"]
    redirect("/")
end


get('/login') do 
    slim(:"users/index")
end

post("/login") do
    username = params[:username]
    password = params[:password]
    
    existing_username = db.execute("SELECT username FROM users WHERE username = ?", username)
    password_for_user = db.execute("SELECT password_digest FROM users WHERE username = ?", username)[0]["password_digest"]
    
    if BCrypt::Password.new(password_for_user) != password || existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/")
    end

    session[:user_id] = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0]["user_id"]
    session[:username] = username
    session[:rank] = db.execute("SELECT rank FROM users WHERE username = ?", username)[0]["rank"]
    redirect("/")
end


get("/logout") do
    session[:user_id] = 0
    session[:chosen_list] = nil
    session[:rank] = nil
    session[:username] = nil
    session[:registration_error] = nil
    session[:login_error] = nil
    redirect("/")
end