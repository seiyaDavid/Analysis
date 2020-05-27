The dataset used for this analysis is too big to be uploaded to Github, to follow along download the dataset from the url below
# https://www.kaggle.com/c/santander-customer-satisfaction
#app.py
from flask import Flask, render_template, request, jsonify, json
from wtforms import StringField, TextField, Form
from wtforms.validators import DataRequired, Length
from flask_sqlalchemy import SQLAlchemy  
 
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///blog.db'
app.config['SECRET_KEY'] = 'cairocoders-ednalan'
 
db = SQLAlchemy(app) 
  
class SearchForm(Form): #create form
 country = StringField('Country', validators=[DataRequired(),Length(max=40)],render_kw={"placeholder": "country"})
 
class Country(db.Model):
 __tablename__ = 'countries'
 
 id = db.Column(db.Integer, primary_key=True)
 name = db.Column(db.String(60), unique=True, nullable = False)
 
 def as_dict(self):
  return {'name': self.name}
   
@app.route('/')
def index():
 form = SearchForm(request.form)
 return render_template('search.html', form=form)
 
@app.route('/countries')
def countrydic():
 res = Country.query.all()
 list_countries = [r.as_dict() for r in res]
 return jsonify(list_countries)
  
@app.route('/process', methods=['POST'])
def process():
 country = request.form['country']
 if country:
  return jsonify({'country':country})
 return jsonify({'error': 'missing data..'})
 
if __name__ == '__main__':
    app.run(debug=True)

//search.html
<html>
<head>
    <meta charset="utf-8">
 <title>Python Flask Jquery Ajax Autocomplete</title>
  <link rel="stylesheet" href="http://code.jquery.com/ui/1.12.1/themes/base/jquery-ui.css">
  <script src="https://code.jquery.com/jquery-1.12.4.js"></script>
  <script src="https://code.jquery.com/ui/1.12.1/jquery-ui.js"></script>
  </head>
<body>
<h1>Python Flask Jquery Ajax Autocomplete using SQLAlchemy database</h1>
<form class="form-inline">
 <div class="form-group">
     {{form.country(class="form-control")}}
   </div>
   <button type="submit" class="btn btn-info">Submit</button>
</form>
<div id="result"></div>
<script>
$(document).ready(function(){
 var countries=[];
 function loadCountries(){
  $.getJSON('/countries', function(data, status, xhr){
   for (var i = 0; i < data.length; i++ ) {
    countries.push(data[i].name);
   }
 });
 };
 loadCountries();
 
 $('#country').autocomplete({
  source: countries, 
 }); 
 
 $('form').on('submit', function(e){
  $.ajax({
   data: {
    country:$('#country').val()
   },
   type: 'POST',
   url : '/process'
  })
  .done(function(data){ 
   if (data.error){
    $('#result').text(data.error).show();
   }
   else {
    $('#result').html(data.country).show()
   }
  })
  e.preventDefault();
 });
}); 
</script>
<style>
.form-control {
    display: block;
    width:300px;
    padding: .375rem .75rem;
    font-size: 1rem;
    line-height: 1.5;
    color: #495057;
    background-color: #fff;
    background-clip: padding-box;
    border: 1px solid #ced4da;
    border-radius: .25rem;
    transition: border-color .15s ease-in-out,box-shadow .15s ease-in-out;
}
.btn {padding: .375rem .75rem; margin-top:10px;}
</style>
  </body>
</html>
