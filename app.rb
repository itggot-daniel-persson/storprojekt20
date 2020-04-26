require "sinatra"
require "sinatra/reloader"
require "slim"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative 'model.rb'
also_reload "./model.rb"
include Model

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

before do 
    if request.post?
        if session[:last_action].nil?
            session[:last_action] = Time.now
        end
        if ((session[:last_action] + 5) > Time.now())
            sleep(2)
        end
        session[:last_action] = Time.now()
        
        session[:ad_creation_feedback] = nil
        session[:registration_error] = nil
        session[:login_error] = nil
    end
end

# before('/') do
#     session[:user_id] = 2
#     session[:username] = "Emrik"
# end

get('/') do 
    empty_result = nil
    search_results = search(params[:search_value])
    if search_results.empty?
        empty_result = "No results. Try another word"
    end
    slim(:"ads/index",locals:{search_results:search_results,empty_result:empty_result})
end

# 
# Shows registration page where you can create a new account. 
# 
get('/users/new') do 
    slim(:"users/new")
end

# 
# Takes form input from '/users/new' with user information and validates it, and then ads it to the database
# 
# @param [String] username Users username
# @param [String] password Users password
# @param [String] password_confirmation Users password confirmation
# @param [String] phone Users phone number
# @param [String] email Users email address
# 
# @see Model#get_from_db
# @see Model#registration_validation
# @see Model#register_user
# 
post("/users/new") do
    username = params[:username]
    password = params[:password]
    password_confirmation = params[:password_confirmation]
    phone = params[:phone]
    email = params[:email]

    session[:registration_error] = nil

    existing_username = get_from_db("username","Users","username",username)
    existing_email = get_from_db("email","Users","email",email)
    existing_phone = get_from_db("phone","Users","phone",phone)

    validation_msg = registration_validation(existing_username,existing_email,existing_phone,username,password,password_confirmation,email,phone)
    
    if !validation_msg.nil?
        session[:registration_error] = validation_msg
        redirect('/users/new')
    end
    password_digest = BCrypt::Password.create(password)
    register_user(username,password_digest,"user",email,phone)
    session[:username] = username
    session[:user_id] = get_from_db("user_id","Users","username",session[:username])[0]["user_id"]
    redirect("/")
end

# 
# Displays login page
# 
get('/users/') do 
    slim(:"users/index")
end

#  
# Takes input from '/users/' and logs a user in with that information.
# First it checks if username is in database. Then it checks if the digested password is equal to the digested password in the database.
# 
# @param [String] username Users inputted username
# @param [String] password Users inputted password
# 
# @see Model#get_from_db
# 
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

# 
# Logs a user out and destroys all session cookies
# 
post("/logout") do 
    session.destroy
    redirect('/')
end

# 
# Shows all ads of a specific user
# 
# @params [Integer] user_id User id to show profile of.
# 
# @see Model#get_from_db
# @see Model#get_public_ads
# 
get('/users/show/:user_id') do 
    user_id = params[:user_id].to_i

    if user_id == session[:user_id]
        my_ads = get_from_db("*","Ads","user_id",user_id)
    else
        my_ads = get_public_ads(user_id)
    end
    user = get_from_db("username","Users","user_id",user_id)[0]

    slim(:"users/show",locals:{my_ads: my_ads,user: user})
end

# 
# Displays '/ads/new' page where a user can create ads. But if you're not logged in it seds you back to the home page '/' 
# It also retrieve fresh categories from the database
# 
# @see Model#not_auth
# @see Model#get_from_db
get('/ads/new') do 
    if not_auth(session[:user_id])
        redirect('/')
    end
    categories = get_from_db("*","Categories",nil,nil)
    slim(:"ads/new", locals:{categories: categories})
end

# 
# Receives form input from '/ads/new' and creates a new ad based on the variables.
# It also verifies that you upload a image file. Otherwise is returns error message "That's not a valid file format"
# 
# @param [String] name Name of the ad
# @param [String] description Description of ad
# @param [Integer] price Price of ad 
# @param [String] location Location of the seller
# @param [String] public If the ad should be public or private
# @param [String] category1 Category 1
# @param [String] category2 Category 2
# @param [String] category3 Category 3
# 
# @see Model#get_ad_id
# @see Model#validate_ad_items
# @see Model#add_new_ad
# @see Model#new_ad_to_categories
# 
post('/ads/new') do
    name = params[:name]
    description = params[:desc]
    price = params[:price]
    location = params[:location]
    public_status = params[:public] 
    categories = [params[:category1],params[:category2],params[:category3]].uniq.reject(&:nil?)
    
    validation = validate_ad_items(name,description,price,price,location)

    ad_id = get_ad_id()
    if !(params["img"].nil?)
        img_ext = File.extname(params["img"]["filename"]).downcase
        if img_ext != ".png" && img_ext != ".jpg" && img_ext != ".jpeg"
            validation = "That's not a valid file format"
            redirect('/ads/new')
        end
        img_path = "#{ad_id.to_s}#{img_ext}"
        File.open('public/img/ads_img/' + ad_id.to_s + img_ext.to_s , "wb") do |f|
            f.write(params['img']["tempfile"].read)
        end
    else
        img_path = nil
    end
    
    if validation.nil?
        session[:ad_creation_feedback] = add_new_ad(name,description,price,location,session[:user_id],public_status,img_path)
        new_ad_to_categories(ad_id,categories)
    else
        session[:ad_creation_feedback] = validation
    end
    redirect('/ads/new')
end

# 
# Displays a specific ad based on the ad_id provided in the path
# 
# @param [Integer] :ad_id The id of a specific ad
# 
# @see Model#get_from_db
# @see Model#get_all_categories
# @see Model#review_dup
# @see Model#get_rating_of_user
# 
get('/ads/:ad_id') do
    no_auth = false
    ad_id = params["ad_id"]
    ad_data = get_from_db("*","Ads","ad_id",ad_id)[0]
    category_data = get_all_categories(ad_id)
    if !category_data.nil?
        ad_data.store("categories", category_data)
    end
    review_dup = review_dup(session[:user_id],ad_data["user_id"])
    if ad_data != nil
        seller_data = get_from_db("*","Users","user_id",ad_data["user_id"])[0]
        seller_rating = get_rating_of_user(ad_data["user_id"])

        if ad_data["public"] == nil && ad_data["user_id"] != session[:user_id]
            no_auth = true
            ad_data = nil
        end
    end
    # Kanske merga seller_data och seller_rating
    session[:edit_ad] = ad_data
    slim(:"ads/show",locals:{ad_info:ad_data, seller_data:seller_data, seller_rating:seller_rating, no_auth:no_auth, review_dup:review_dup})
end

# 
# Displays the edit page for a specific ad.
# It also checks if you have the corret authorization to edit the ad.
# 
# @param [Integer] :ad_id Id of the ad thats going to be edited.
# 
get('/ads/:ad_id/edit') do
    ad_data = session[:edit_ad]
    no_auth = false
    if ad_data["user_id"] != session[:user_id] && session[:rank] != "admin"
        no_auth = true
        ad_data = nil
    end
    slim(:"ads/edit",locals:{ad_info:ad_data,no_auth:no_auth})
end

# 
# Takes input from '/ads/:ad_id/edit' and validates it and updates the ad information in the database. 
# 
# @param [Integer] :ad_id Id of the ad thats going to be updated.
# 
# @see Model#validate_ad_items
# @see Model#update_ad
# 
post('/ads/:ad_id/update') do
    ad_id = session[:edit_ad]["ad_id"]
    img_path = params[:old_img]
    
    if (params[:old_img] != params[:img]) && !(params[:img].nil?)
        img_ext = File.extname(params["img"]["filename"]).downcase
        if img_ext != ".png" && img_ext != ".jpg" && img_ext != ".jpeg"
            session[:edit_ad_feedback] = "That's not a valid file format"
            redirect back
        end
        File.delete('public/img/ads_img/' + img_path) if img_path != nil && File.exist?('public/img/ads_img/' + img_path)
        img_path = "#{ad_id.to_s}#{img_ext}"
        File.open('public/img/ads_img/' + ad_id.to_s + img_ext.to_s , "wb") do |f|
            f.write(params['img']["tempfile"].read)
        end
    end
    validation = validate_ad_items(params[:name],params[:desc],params[:price],params[:disc_price],session[:edit_ad]["location"])
    if validation.nil?
        update_ad(ad_id,img_path,params[:name],params[:desc],params[:price],params[:disc_price])
    else
        session[:edit_ad_feedback] = validation
    end
    redirect('/')
end

# 
# Deletes a specified ad and its corresponding categories and pictures.
# 
# @see Model#delete_ad
# 
post('/ads/destory') do 
    ad_id = session[:edit_ad]["ad_id"]
    delete_ad(ad_id,session[:user_id],session[:rank])
    redirect('/')
end

# 
# Takes rating input from '/ads/:ad_id' and adds it to the database.
# 
# @param [String] rating The inputted
# 
# @see Model#add_new_review
# 
post('/ads/review') do 
    rating = params[:rating].to_i
    user_id = session[:edit_ad]["user_id"]
    ad_id = session[:edit_ad]["ad_id"]
    reviewer_id = session[:user_id]
    add_new_review(user_id,reviewer_id,rating)
    redirect back
end

post('/ads/buy_item') do 
    if !not_auth(session[:user_id])
        ad_id = session[:edit_ad]["ad_id"]
        buyer_id = session[:user_id]
        ad_exist = get_from_db("*","Ads","ad_id",ad_id)
        if ad_exist
            buy_ad(buyer_id,ad_id)
        end
    end
    redirect back
end

get('/admin') do
    transactions = get_from_db("*","Transactions",nil,nil)
    user_info = get_from_db("*","Users",nil,nil)
    slim(:"admin/index", locals:{transactions: transactions, user_info: user_info})
end