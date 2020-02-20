# Inga sessions eller params
# Skicka med som argument 




def connect_to_db()
    db = SQLite3::Database.new("db/database.db")
    db.results_as_hash = true
    return db
end

def get_from_db(column, table, where, value)
    db = connect_to_db()
    if where.nil? || value.nil?
        return db.execute("SELECT #{column} FROM #{table}")
    else
        return db.execute("SELECT #{column} FROM #{table} WHERE #{where} = ?",value)
    end
end

def get_public_ads(user_id)
    db = connect_to_db()
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

def add_new_ad(name,description,price,location,user_id,public_status)
    db = connect_to_db()
    if name.empty? || description.empty? || price.empty? || location.empty?
        return "You missed to fill out a field"
    elsif !(price.to_i.to_s == price)
        return"Please enter a valid price. Ex 399"
    elsif name.length >= 1000 || description.length >= 1000 || location.length >= 1000
        return "Whoa, stop there. I dont believe your text is that long"
    else
        db.execute("INSERT INTO Ads (name, description, price, discounted_price, location, user_id, bought, public) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",name, description, price, price, location,user_id, "no", public_status)
        return "Sucess! Your ad has been added"
    end
end

def not_auth()
    if session[:user_id] == nil
        return true
    else
        return false
    end
end