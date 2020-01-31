require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

def not_auth()
    if session[:user_id] == nil
        return true
    else
        return false
    end
end

get('/') do 
    # if session[:search_results].empty?
    #     session[:search_results] = db.execute("SELECT * FROM Ads")
    # end
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
    p existing_email
    p existing_email.empty?
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
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/login")
    end

    password_for_user = db.execute("SELECT password_digest FROM users WHERE username = ?", username)[0]["password_digest"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/login")
    end

    session[:user_id] = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0]["user_id"]
    session[:username] = username
    session[:rank] = db.execute("SELECT rank FROM users WHERE username = ?", username)[0]["rank"]
    redirect("/")
end

# Hitta ett sätt att resetta alla
get("/logout") do 
    session[:user_id] = nil
    session[:rank] = nil
    session[:username] = nil
    session[:registration_error] = nil
    session[:login_error] = nil
    slim(:"ads/index")
end

get('/ads/new') do 
    if session[:user_id] == nil
        redirect("/")
    end
    slim(:"ads/new")
end

get('/ads/edit') do 
    my_ads = db.execute("SELECT * FROM Ads WHERE user_id = ?",session[:user_id])
    slim(:"ads/edit",locals:{my_ads: my_ads})
end


post('/ads/create_ad') do
    name = params[:name]
    description = params[:desc]
    price = params[:price]
    location = params[:location]

    if name.empty? || description.empty? || price.empty? || location.empty?
        session[:ad_creation_error] = "You missed to fill out a field"
        redirect('/ads/new')
    elsif !(price.to_i.to_s == price)
        session[:ad_creation_error] = "Please enter a valid price. Ex 399"
        redirect('/ads/new')
    elsif name.length >= 1000 || description.length >= 1000 || location.length >= 1000
        session[:ad_creation_error] = "Whoa, stop there. I dont beleive your text is that long"
        redirect('/ads/new')
    end

    db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought) VALUES (?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,session[:user_id], "no")

    redirect('/')
end

post('/search') do
    search_value = params[:search_value]

    session[:search_results] = db.execute("SELECT * FROM Ads WHERE name LIKE '%#{search_value}%'")
    redirect('/')
end

get('/ads/:ad_id') do
    ad_id = params["ad_id"]
    ad_data = db.execute("SELECT * FROM Ads WHERE ad_id = ?",ad_id)
    slim(:"ads/show",locals:{ad_info:ad_data})
end

post('/ads/:ad_id/update') do

end