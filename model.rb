# Inga sessions eller params
# Skicka med som argument 




def db()
    db = SQLite3::Database.new("db/database.db")
    db.results_as_hash = true
    return db
end

def get_from_db(column, table, where, value)
    if where.nil? || value.nil?
        return db.execute("SELECT #{column} FROM #{table}")
    else
        return db.execute("SELECT #{column} FROM #{table} WHERE #{where} = ?",value)
    end
end

def get_public_ads(user_id)
    return db.execute("SELECT * FROM Ads WHERE user_id = ? AND public = ?",user_id, "on")
end

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

def add_new_ad(name,description,price,location,user_id,public_status,img)
    if name.empty? || description.empty? || price.empty? || location.empty?
        return "You missed to fill out a field"
    elsif !(price.to_i.to_s == price)
        return"Please enter a valid price. Ex 399"
    elsif name.length >= 1000 || description.length >= 1000 || location.length >= 1000
        return "Whoa, stop there. I dont believe your text is that long"
    else
        db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought, public, image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,user_id, "no", public_status, img)
        return "Sucess! Your ad has been added"
    end
end

def new_ad_to_categories(ad_id,category_id)

    db.execute("INSERT INTO Category_relation (ad_id, category_id) VALUES (?, ?)",ad_id,category_id)
end

def update_ad(ad_id,image,name,desc,price,disc_price)
    db.execute("UPDATE Ads SET image = ?,name = ?,desc = ?,price = ? WHERE ad_id = ?",)
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

def add_new_review(user_id,reviwer_id,rating)
    db.execute("INSERT INTO Reviews (user_id, reviewer_id, rating) VALUES (?,?,?)", user_id, reviwer_id, rating)
end

def not_auth()
    if session[:user_id] == nil
        return true
    else
        return false
    end
end