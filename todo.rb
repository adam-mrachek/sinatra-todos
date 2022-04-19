# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'

require_relative "database_persistence"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'pry'
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

helpers do
  def list_completed?(list)
    list[:todos_count] > 0 && list[:todos_remaining] == 0
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo_name(text)
  if !(1..100).cover?(text.size)
    'Todo must be between 1 and 100 characters.'
  end
end

def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = "The requested list was not found."
  redirect "/lists"
end

get '/' do
  redirect '/lists'
end

# View all of the lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Render single todo list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todos = @storage.get_todos(@list_id)
  erb :show, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Edit existing todo list
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit, layout: :layout
end

# Update list if input is validated
patch '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  if (error = error_for_list_name(list_name))
    session[:error] = error
    redirect "/lists/#{@list_id}/edit"
  else
    @storage.update_list(@list_id, list_name)
    @list[:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo list
post '/lists/:id/delete' do
  id = params[:id].to_i
  @storage.delete_list(id)
  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect '/lists'
  end
end

# Add a todo to a todo list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  if (error = error_for_todo_name(text))
    session[:error] = error
    erb :show, layout: :layout
  else
    @storage.add_todo_to_list(@list_id, text)
    session[:success] = "You added a todo to #{@list[:name]}."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(@list_id)
  @storage.delete_todo(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status
  else
    session[:success] = "Todo deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update todo completion status
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @list = load_list(@list_id)

  is_completed = params[:completed] == 'true'
  @storage.update_todo_status(@list_id, todo_id, is_completed)
  session[:success] = "Todo has been updated."

  redirect "/lists/#{@list_id}"
end

# Mark all todos on a list as completed
post '/lists/:list_id/complete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @storage.mark_all_todos_complete(@list_id)
  session[:success] = "You have marked all todos as completed."

  redirect "/lists/#{@list_id}"
end