# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'pry'

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

before do
  session[:lists] ||= []
  session[:number] ||= 0
end

helpers do
  def list_completed?(list)
    list[:todos].all? { |todo| todo[:completed] } && list[:todos].size > 0
  end

  def active_todos(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo_name(text)
  if !(1..100).cover?(text.size)
    'Todo must be between 1 and 100 characters.'
  end
end

get '/' do
  redirect '/lists'
end

# View all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Render single todo list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first
  erb :show, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = session[:number]
    session[:lists] << { name: list_name, todos: [], id: id }
    session[:success] = 'The list has been created.'
    session[:number] += 1
    redirect '/lists'
  end
end

# Edit existing todo list
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first
  erb :edit, layout: :layout
end

# Update list if input is validated
patch '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first

  if (error = error_for_list_name(list_name))
    session[:error] = error
    redirect "/lists/#{@list_id}/edit"
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo list
delete '/lists/:id' do
  session[:lists].delete_if { |list| list[:id] == params[:id].to_i }
  session[:success] = "The list has been deleted."
  redirect '/lists'
end

# Add a todo to a todo list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  text = params[:todo].strip
  @list = session[:lists].select { |list| list[:id] == @list_id }.first

  if (error = error_for_todo_name(text))
    session[:error] = error
    erb :show, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "You added a todo to #{@list[:name]}."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first
  @list[:todos].delete_at(@todo_id)
  session[:success] = "Todo deleted."

  redirect "/lists/#{@list_id}"
end

# Update todo completion status
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first

  is_completed = params[:completed] == 'true'
  todo = @list[:todos][todo_id]
  todo[:completed] = is_completed
  session[:success] = "Todo has been updated."

  redirect "/lists/#{@list_id}"
end

# Mark all todos on a list as completed
post '/lists/:list_id/complete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists].select { |list| list[:id] == @list_id }.first
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "You have marked all todos as completed."

  redirect "/lists/#{@list_id}"
end