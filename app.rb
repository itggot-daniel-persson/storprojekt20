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

# before do 
#     if session[:user_id] != nil 
#         redirect('/')
#     end
# end

get('/') do 
    # if session[:search_results].empty?
    #     session[:search_results] = db.execute("SELECT * FROM Ads")
    # end
    slim(:"ads/index")
end

get('/users/new') do 
    slim(:"users/new")
end

post("/users/new") do
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


get('/users/') do 
    slim(:"users/index")
end

post("/users/") do
    username = params[:username]
    password = params[:password]
    
    existing_username = db.execute("SELECT username FROM users WHERE username = ?", username)
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    password_for_user = db.execute("SELECT password_digest FROM users WHERE username = ?", username)[0]["password_digest"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
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
    if not_auth()
        redirect('/')
    end
    # Get categories
    categories = db.execute("SELECT name FROM Categories")
    slim(:"ads/new", locals:{categories: categories})
end

get('/users/show/:user_id') do 

    user_id = params[:user_id].to_i
    p params[:user_id].to_i
    p session[:user_id]

    if user_id == session[:user_id]
        my_ads = db.execute("SELECT * FROM Ads WHERE user_id = ?",user_id)
    else
        my_ads = db.execute("SELECT * FROM Ads WHERE user_id = ? AND public = ?",user_id, "on")
    end
    slim(:"users/show",locals:{my_ads: my_ads})
end


post('/ads/new') do
    name = params[:name]
    description = params[:desc]
    price = params[:price]
    location = params[:location]
    public_status = params[:public]

    if name.empty? || description.empty? || price.empty? || location.empty?
        session[:ad_creation_error] = "You missed to fill out a field"
        redirect('/ads/new')
    elsif !(price.to_i.to_s == price)
        session[:ad_creation_error] = "Please enter a valid price. Ex 399"
        redirect('/ads/new')
    elsif name.length >= 1000 || description.length >= 1000 || location.length >= 1000
        session[:ad_creation_error] = "Whoa, stop there. I dont believe your text is that long"
        redirect('/ads/new')
    end

    db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought, public) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,session[:user_id], "no", public_status)

    redirect('/')
end


post('/search') do
    session[:search_results_empty] = nil

    search_value = "%#{params[:search_value]}%"
    
    session[:search_results] = db.execute("SELECT * FROM Ads WHERE name LIKE ? AND public = ? ",search_value, "on")
    if session[:search_results].empty?
        session[:search_results_empty] = "No results. Try another word"
    end
    redirect('/')
end

get('/ads/:ad_id') do
    no_auth = false
    ad_id = params["ad_id"]
    ad_data = db.execute("SELECT * FROM Ads WHERE ad_id = ?",ad_id)[0]
    # Kanske göra om.
    seller_data = db.execute("SELECT * FROM Users WHERE user_id = ?",ad_data["user_id"])[0]
    seller_rating_raw = db.execute("SELECT rating FROM Reviews WHERE user_id = ?",ad_data["user_id"])

    seller_rating_formatted = []
    seller_rating_raw.each do |rating|
        seller_rating_formatted << rating["rating"]
    end
    seller_rating = (seller_rating_formatted.reduce(:+)).to_f / seller_rating_formatted.size.to_f
    p seller_rating_raw
    p seller_rating

    if ad_data["public"] == nil && ad_data["user_id"] != session[:user_id]
        no_auth = true
        ad_data = nil
    end
    # Kanske merga seller_data och seller_rating
    slim(:"ads/show",locals:{ad_info:ad_data, seller_data:seller_data, seller_rating:seller_rating, no_auth:no_auth})
end

post('/ads/:ad_id/update') do

end