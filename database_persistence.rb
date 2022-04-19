require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'todos')
          end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
    SELECT lists.*, 
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining
      FROM lists
      LEFT JOIN todos
      ON lists.id = todos.list_id
      WHERE lists.id = $1
      GROUP BY lists.id
      ORDER BY todos_remaining DESC;
    SQL
    result = query(sql, id)

    tuple = result.first
    tuple_to_list_hash(tuple)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*, 
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, true)) AS todos_remaining
        FROM lists
        LEFT JOIN todos
        ON lists.id = todos.list_id
        GROUP BY lists.id
        ORDER BY todos_remaining DESC;
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    query("DELETE FROM todos WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def update_list(list_id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, list_id)
  end

  def add_todo_to_list(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, todo_name)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_complete(list_id)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2"
    query(sql, true, list_id)
  end

  def get_todos(id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, id)
    result.map do |tuple|
      {id: tuple["id"].to_i, name: tuple["name"], completed: tuple["completed"] == 't'}
    end
  end

  def tuple_to_list_hash(tuple)
    {
      id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining: tuple["todos_remaining"].to_i
    }
  end
end