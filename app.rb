require "sinatra"
require "sinatra/reloader"
require "slim"
require "sqlite3"
require "bcrypt"
require "byebug"
require_relative 'model.rb'
also_reload "./model.rb"

enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

before do 
#     if session[:user_id] != nil 
#         redirect('/')
#     end

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

get('/users/new') do 
    slim(:"users/new")
end

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

post("/logout") do 
    session.destroy
    redirect('/')
end

get('/ads/new') do 
    if not_auth()
        redirect('/')
    end
    # Get categories
    categories = get_from_db("*","Categories",nil,nil)
    slim(:"ads/new", locals:{categories: categories})
end

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

post('/ads/new') do
    name = params[:name]
    description = params[:desc]
    price = params[:price]
    location = params[:location]
    public_status = params[:public] 
    categories = [params[:category1],params[:category2],params[:category3]].uniq.reject(&:nil?)

    ad_id = get_ad_id()
    if !(params["img"].nil?)
        img_ext = File.extname(params["img"]["filename"]).downcase
        if img_ext != ".png" && img_ext != ".jpg" && img_ext != ".jpeg"
            session[:ad_creation_feedback] = "That's not a valid file format"
            redirect('/ads/new')
        end
        img_path = "#{ad_id.to_s}#{img_ext}"
        File.open('public/img/ads_img/' + ad_id.to_s + img_ext.to_s , "wb") do |f|
            f.write(params['img']["tempfile"].read)
        end
    else
        img_path = nil
    end
    
    validation = validate_ad_items(name,description,price,price,location)
    if validation.nil?
        add_new_ad(name,description,price,location,session[:user_id],public_status,img_path)
        new_ad_to_categories(ad_id,categories)
    else
        session[:ad_creation_feedback] = validation
    end
    redirect('/ads/new')
end

get('/ads/:ad_id') do
    no_auth = false
    ad_id = params["ad_id"]
    ad_data = get_from_db("*","Ads","ad_id",ad_id)[0]
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

get('/ads/:ad_id/edit') do
    ad_data = session[:edit_ad]
    no_auth = false
    if ad_data["user_id"] != session[:user_id] && session[:rank] != "admin"
        no_auth = true
        ad_data = nil
    end
    slim(:"ads/edit",locals:{ad_info:ad_data,no_auth:no_auth})
end

post('/ads/:ad_id/update') do
    ad_id = session[:edit_ad]["ad_id"]
    img_path = params[:old_img]
    
    if (params[:old_img] != params[:img]) && !(params[:img].nil?)
        img_ext = File.extname(params["img"]["filename"]).downcase
        if img_ext != ".png" && img_ext != ".jpg" && img_ext != ".jpeg"
            session[:edit_ad_feedback] = "That's not a valid file format"
            redirect back
        end
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
    redirect back
end

post('/ads/destory') do 
    ad_id = session[:edit_ad]["ad_id"]
    delete_ad(ad_id,session[:user_id],session[:rank])
    redirect('/')
end

post('/ads/review') do 
    rating = params[:rating].to_i
    user_id = session[:edit_ad]["user_id"]
    ad_id = session[:edit_ad]["ad_id"]
    reviewer_id = session[:user_id]
    add_new_review(user_id,reviewer_id,rating)
    redirect back
end

