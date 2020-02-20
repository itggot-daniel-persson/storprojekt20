require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative 'model.rb'

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

# before do 
#     if session[:user_id] != nil 
#         redirect('/')
#     end
# end

before('/') do
    session[:user_id] = 2
    session[:username] = "Emrik"
end

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

    existing_username = get_from_db("username","Users","username",username)
    existing_email = get_from_db("email","Users","email",email)
    existing_phone = get_from_db("phone","Users","phone",phone)

    if !existing_username.empty?
        session[:registration_error] = "Username is taken"
        redirect("/users/new")
    elsif password != password_confirmation
        session[:registration_error] = "Password do not match"
        redirect("/users/new")
    elsif !existing_email.empty?
        session[:registration_error] = "Email is taken"
        redirect("/users/new")
    elsif !existing_phone.empty?
        session[:registration_error] = "Phone is taken"
        redirect("/users/new")
    end
    password_digest = BCrypt::Password.create(password)
    register_user(username,password_digest,"user",email,phone)
    session[:username] = username
    session[:user_id] = get_from_db("user_id","Users","username",session[:username])[0]["user_id"]
    redirect("/")
end


get('/users/') do 
    slim(:"users/index")
end

post("/users/") do
    username = params[:username]
    password = params[:password]
    
    existing_username = get_from_db("username","Users","username",username)
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    password_for_user = get_from_db("password_digest","Users","username",username)[0]["password_digest"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    session[:user_id] = get_from_db("user_id","Users","username",username)[0]["user_id"]

    session[:username] = username
    session[:rank] = get_from_db("rank","Users","username",username)[0]["rank"]
    redirect("/")
end

get("/logout") do 
    session.destroy
    slim(:"ads/index")
end

get('/ads/new') do 
    if not_auth()
        redirect('/')
    end
    # Get categories
    categories = get_from_db("name","Categories",nil,nil)
    slim(:"ads/new", locals:{categories: categories})
end

get('/users/show/:user_id') do 
    user_id = params[:user_id].to_i
    p params[:user_id].to_i
    p session[:user_id]

    if user_id == session[:user_id]
        #my_ads = db.execute("SELECT * FROM Ads WHERE user_id = ?",user_id)
        my_ads = get_from_db("*","Ads","user_id",user_id)
    else
        #my_ads = db.execute("SELECT * FROM Ads WHERE user_id = ? AND public = ?",user_id, "on")
        my_ads = get_public_ads(user_id)
    end
    slim(:"users/show",locals:{my_ads: my_ads})
end


post('/ads/new') do
    name = params[:name]
    description = params[:desc]
    price = params[:price]
    location = params[:location]
    public_status = params[:public] 
    p session[:user_id]
    session[:ad_creation_feedback] = add_new_ad(name,description,price,location,session[:user_id],public_status)
    #db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought, public) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,session[:user_id], "no", public_status)

    redirect('/ads/new')
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
    ad_data = get_from_db("*","Ads","ad_id",ad_id)[0]
    #ad_data = db.execute("SELECT * FROM Ads WHERE ad_id = ?",ad_id)[0]

    seller_data = get_from_db("*","Users","user_id",ad_data["user_id"])[0]
    seller_rating = get_rating_of_user(ad_data["user_id"])

    if ad_data["public"] == nil && ad_data["user_id"] != session[:user_id]
        no_auth = true
        ad_data = nil
    end
    # Kanske merga seller_data och seller_rating
    slim(:"ads/show",locals:{ad_info:ad_data, seller_data:seller_data, seller_rating:seller_rating, no_auth:no_auth})
end

post('/ads/review') do 
    rating = params[:rating]
    user_id = params[:user_id]
    ad_id = params[:ad_id]
    #Kanske verifiera att personen är inloggad. Dock gör jag det innan.
    columns = ["user_id","reviewer_id","rating"]

    db.execute("INSERT INTO Reviews (user_id, reviewer_id, rating) VALUES (?,?,?)", user_id, session[:user_id], rating)
    redirect('/')
end

post('/ads/:ad_id/update') do

end

post('/ads/destory') do 
    ad_id = params[:ad_id]
    #Is user ad owner?
    owner_id = get_from_db("user_id","Ads","ad_id",ad_id)[0]["user_id"]
    #owner_id = db.execute("SELECT user_id FROM Ads WHERE ad_id = ?",ad_id)[0]["user_id"]

    if session[:user_id] == owner_id
        db.execute("DELETE FROM Ads WHERE ad_id = ?", ad_id)
        p "success"
    else
        #Ad feedback for error
        p "fail"
    end
    redirect('/')
end