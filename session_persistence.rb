class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
    @session[:list_number] ||= 0
    @session[:todo_number] ||= 0
  end

  def find_list(id)
    @session[:lists].select { |list| list[:id] == id }.first
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = @session[:list_number]
    @session[:lists] << { name: list_name, todos: [], id: id }
    @session[:list_number] += 1
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list(list_id, new_name)
    list = find_list(list_id)
    list[:name] = new_name
  end

  def add_todo_to_list(list_id, todo_name)
    id = @session[:todo_number]
    list = find_list(list_id)

    list[:todos] << { name: todo_name, id: id, completed: false }
    @session[:todo_number] += 1
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].select { |todo| todo[:id] == todo_id}.first
    todo[:completed] = new_status
  end

  def mark_all_todos_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end
end
