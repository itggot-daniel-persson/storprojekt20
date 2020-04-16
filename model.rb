

#
# Connects to the database
#
# @return [<Type>] Returns the database as a hash
#
def db()
    db = SQLite3::Database.new("db/database.db")
    db.results_as_hash = true
    return db
end

#
# Get different items from database depending on the arguments given
#
# @param [String] column , The column to be searched
# @param [String] table , The table to be searched
# @param [String] where , Optional argument if you want to retrieve SQL rows where a specific value matches
# @param [String] value , The value to be searched
#
# @return [Hash] A hash with retrieved items from SQL database
#
def get_from_db(column, table, where, value)
    if where.nil? || value.nil?
        return db.execute("SELECT #{column} FROM #{table}")
    else
        return db.execute("SELECT #{column} FROM #{table} WHERE #{where} = ?",value)
    end
end

#
# Get all the public ads from a user
#
# @param [Integer] user_id , Id of a user
#
# @return [Hash] A hash with all the public ads of a specific user.
#
def get_public_ads(user_id)
    return db.execute("SELECT * FROM Ads WHERE user_id = ? AND public = ?",user_id, "on")
end

#
# Gets the rating of a user
#
# @param [Integer] user_id , The user id to calculate average reviews on a user
#
# @return [Float] A value from 0.0 to 5.0
#
def get_rating_of_user(user_id)
    seller_rating_raw = get_from_db("rating","Reviews","user_id",user_id)

    seller_rating_formatted = []
    seller_rating_raw.each do |rating|
        seller_rating_formatted << rating["rating"]
    end

    seller_rating = ((seller_rating_formatted.reduce(:+)).to_f / seller_rating_formatted.size.to_f).to_f
    return seller_rating.round(1)
end

def register_user(username,password_digest,rank,email,phone)
    db.execute("INSERT INTO Users (username, password_digest, rank, email, phone) VALUES (?, ?, ?, ?, ?)", username, password_digest, rank, email, phone)
end

def registration_validation(existing_username,existing_email,existing_phone,username,password,password_confirmation,email,phone)
    if !existing_username.empty?
        return "Username is taken"
    elsif !existing_email.empty?
        return "Email is taken"
    elsif !existing_phone.empty?
        return "Phone is taken"
    elsif (21 < username.length) || (username.length < 2)
        return "Username needs to be between 3 and 20 characters. You have #{username.length} characters" 
    elsif password.scan(/^(?=.*[a-zA-Z])(?=.*[0-9]).{8,}$/).empty?
        return "Your password needs to contain at least a lowercase letter, a uppercase, a digit and be 8 characters long"
    elsif password != password_confirmation
        return "Password do not match"
    elsif phone.length != 10
        return "Your phone is not 10 digits long"
    elsif phone.scan(/\d/).empty?
        return "You have inputted a invalid phone number"
    end
end

def validate_ad_items(name,description,price,disc_price,location)
    if name.empty? || description.empty? || price.empty? || location.empty?
        return "You missed to fill out a field"
    elsif !(price.to_i.to_s == price) || price.length > 10 || !(disc_price.to_i.to_s == disc_price) || disc_price.length > 10
        return"Please enter a valid price. Ex 399"
    elsif name.length >= 500 || description.length >= 500 || location.length >= 20
        return "Whoa, stop there. I dont believe your text is that long"
    else
        return nil
    end
end

def add_new_ad(name,description,price,location,user_id,public_status,img)
    db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought, public, image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,user_id, "no", public_status, img)
    return "Sucess! Your ad has been added"
end

#
# Ad new a to categories
#
# @param [Integer] ad_id of the ad that categories should be added to
# @param [Integer] category_id The id of the category that's going to be connented with ad_id
#
def new_ad_to_categories(ad_id,category_id)
    category_id.each do |category_id|
        db.execute("INSERT INTO Category_relation (ad_id, category_id) VALUES (?, ?)",ad_id,category_id)
    end
end

def update_ad(ad_id,image,name,desc,price,disc_price)
    db.execute("UPDATE Ads SET image = ?,name = ?,description = ?,price = ?,discounted_price = ? WHERE ad_id = ?",image,name,desc,price,disc_price,ad_id)
end

def delete_ad(ad_id,current_user,rank)
    #Is user ad owner?
    owner_id = get_from_db("user_id","Ads","ad_id",ad_id)[0]["user_id"]
    img_path = get_from_db("image","Ads","ad_id",ad_id)[0]["image"]
    if current_user == owner_id || rank == "admin"
        db.execute("DELETE FROM Ads WHERE ad_id = ?", ad_id)
        db.execute("DELETE FROM Category_relation WHERE ad_id = ?",ad_id)
        File.delete('public/img/ads_img/' + img_path) if File.exist?('public/img/ads_img/' + img_path)
        p "success"
    else
        #Ad feedback for error
        p "fail"
    end

end

def search(search_value)
    if search_value == ""
        results = get_from_db("*","Ads",nil,nil)
    else
        search_string = "%#{search_value}%"
        results = db.execute("SELECT * FROM Ads WHERE name LIKE ? AND public = ? ",search_string, "on")
    end
    results.each do |ad|
        ad["seller"] = get_from_db("username","Users","user_id",ad["user_id"])[0]["username"]
    end
    return results
end

def get_ad_id()
    count = db.execute("SELECT seq FROM sqlite_sequence WHERE name = 'Ads'")[0]["seq"] + 1
    return count
end

def review_dup(reviewer_id,user_id)
    return db.execute("SELECT user_id FROM Reviews WHERE reviewer_id = ? AND user_id = ?",reviewer_id,user_id)
end

def add_new_review(user_id,reviewer_id,rating)
    dup_check = review_dup(reviewer_id,user_id)
    #Fixa så error visas på slim
    if dup_check.empty?
        if rating.between?(0, 5)
            puts "Success"
            db.execute("INSERT INTO Reviews (user_id, reviewer_id, rating) VALUES (?,?,?)", user_id, reviewer_id, rating)
        end
    end
end

def not_auth()
    if session[:user_id] == nil
        return true
    else
        return false
    end
end