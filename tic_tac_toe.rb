class Board
  WINNING_LINES = [[1, 2, 3], [4, 5, 6], [7, 8, 9], # Rows
                   [1, 4, 7], [2, 5, 8], [3, 6, 9], # Columns
                   [1, 5, 9], [3, 5, 7]] # Diagonals

  def initialize
    @squares = {}
    reset
  end

  def []=(num, marker)
    @squares[num].marker = marker
  end

  def [](num)
    @squares[num].marker
  end

  def unmarked_keys
    @squares.keys.select { |key| @squares[key].unmarked? }
  end

  def draw
    puts <<-MSG
          |     |
       #{@squares[1]}  |  #{@squares[2]}  |  #{@squares[3]}
          |     |
     -----+-----+-----
          |     |
       #{@squares[4]}  |  #{@squares[5]}  |  #{@squares[6]}
          |     |
     -----+-----+-----
          |     |
       #{@squares[7]}  |  #{@squares[8]}  |  #{@squares[9]}
          |     |

    MSG
  end

  def full?
    unmarked_keys.empty?
  end

  def middle_square_available?
    @squares[5].unmarked?
  end

  def someone_won?
    !!winning_marker
  end

  def winning_marker
    WINNING_LINES.each do |line|
      squares = @squares.values_at(*line)
      return squares[0].marker if three_identical_markers?(squares)
    end
    nil
  end

  def reset
    (1..9).each { |key| @squares[key] = Square.new }
  end

  def lines_with_twin_markings_and_unmarked
    twin_marked_lines = WINNING_LINES.select do |line|
      squares = @squares.values_at(*line)
      twin_markers_and_unmarked?(squares)
    end
    twin_marked_lines.empty? ? nil : twin_marked_lines
  end

  def twin_markers_and_unmarked?(squares)
    squares.uniq(&:marker).size == 2 && squares.count(&:unmarked?) == 1
  end

  private

  def three_identical_markers?(squares)
    squares.all?(&:marked?) && squares.uniq(&:marker).size == 1
  end
end

class Square
  INITIAL_MARKER = ' '

  attr_accessor :marker

  def initialize(marker = INITIAL_MARKER)
    @marker = marker
  end

  def to_s
    @marker
  end

  def unmarked?
    marker == INITIAL_MARKER
  end

  def marked?
    !unmarked?
  end
end

class Player
  attr_accessor :wins
  attr_reader :name, :marker
end

class Human < Player
  def initialize
    set_name
    set_marker
  end

  def set_name
    answer = ''
    loop do
      puts "Please enter your name"
      answer = gets.chomp
      break unless answer.strip.empty?
      puts "Sorry, that is not a valid name.\n\n"
    end
    @name = answer
  end

  def set_marker
    answer = ''
    loop do
      puts "\nWhich marker would you like for this game?"
      puts "(pick any letter or number)"
      answer = gets.chomp.upcase
      break if answer.strip.size == 1
      puts "Sorry, that is not a valid marker\n"
    end
    @marker = answer
  end

  def go_first?
    answer = ''
    loop do
      puts "Would you like to mark the first square in this round? (y/n)"
      answer = gets.chomp.downcase
      break if ['y', 'n'].include?(answer)
      puts "Sorry, that's not a valid answer\n\n"
    end
    answer == 'y'
  end

  def choose_square(board)
    puts "Please select a square (#{joinor(board.unmarked_keys)})"
    square = ''
    loop do
      square = gets.to_i
      break if board.unmarked_keys.include?(square)
      puts "Sorry, that's not a valid square"
    end
    board[square] = @marker
  end

  private

  def joinor(numbers, separater = ', ', conjunction = 'or')
    case numbers.size
    when 1
      numbers[0]
    when 2
      numbers.join(" #{conjunction} ")
    else
      "#{numbers[0..-2].join(separater)}, #{conjunction} #{numbers.last}"
    end
  end
end

class Computer < Player
  def initialize(human_marker)
    @name = ['Blue Chip', 'Kazaam', 'Steel'].sample
    @marker = ('A'..'Z').to_a.delete_if { |i| i == human_marker }.sample
    display_name_and_marker
  end

  def display_name_and_marker
    puts "\nYour opponent for this game is #{@name} who will use the letter "\
    "#{@marker} as a marker\n\n"
  end

  def choose_square(board)
    if board.lines_with_twin_markings_and_unmarked
      defensive_move(board) unless winning_move(board)
    elsif board.middle_square_available?
      mark_middle_square(board)
    else
      mark_random_square(board)
    end
  end

  private

  def winning_move(board)
    return nil if lines_with_winning_square(board).empty?
    board[select_winning_square(board)] = @marker
  end

  def lines_with_winning_square(board)
    board.lines_with_twin_markings_and_unmarked.select do |line|
      line.any? { |square| board[square] == @marker }
    end
  end

  def select_winning_square(board)
    lines_with_winning_square(board).sample.select do |square|
      board[square] != @marker
    end.first
  end

  def defensive_move(board)
    board[select_square_to_defend(board)] = @marker
  end

  def select_square_to_defend(board)
    board.lines_with_twin_markings_and_unmarked.sample.select do |square|
      board.unmarked_keys.include?(square)
    end.first
  end

  def mark_middle_square(board)
    board[5] = @marker
  end

  def mark_random_square(board)
    board[board.unmarked_keys.sample] = @marker
  end
end

class TTTgame
  FIRST_MOVER = :choose # possible settings are [:man, :machine, :choose]

  attr_reader :board, :human, :computer

  def initialize
    display_welcome_message
    @board = Board.new
    @human = Human.new
    @computer = Computer.new(human.marker) # Computer cannot pick human marker
  end

  def play
    loop do # New game
      reset_game_and_score
      announce_game_start
      loop do # Current game to five
        play_round # Current round
        display_results
        break if someone_won_game? || !play_next_round?
        reset_for_new_round
      end
      display_winner if someone_won_game?
      play_new_game? ? display_new_game_message : break
    end
    display_goodbye_message
  end

  private

  def display_welcome_message
    clear
    puts "Welcome to Tic Tac Toe\n\n"
  end

  def reset_game_and_score
    reset_first_mover
    reset_current_score
    reset_board
  end

  def reset_first_mover
    @current_marker = case FIRST_MOVER
                      when :man
                        human.marker
                      when :machine
                        computer.marker
                      else
                        human.go_first? ? human.marker : computer.marker
                      end
    clear
  end

  def reset_current_score
    human.wins = 0
    computer.wins = 0
  end

  def reset_board
    board.reset
  end

  def announce_game_start
    puts "The first player to win five rounds wins the game"
    display_first_mover
    puts "\nPress 'enter' to begin"
    gets.chomp
    clear
  end

  def display_first_mover
    if @current_marker == human.marker
      puts "#{human.name} starts the game"
    else
      puts "#{computer.name} starts the game."
    end
  end

  def display_board
    puts "#{human.name} uses #{human.marker}. "\
    "#{computer.name} uses #{computer.marker}."
    board.draw
  end

  def play_round
    display_board if human_turn?
    loop do
      current_player_moves
      toggle_current_marker
      break increment_winner_score if board.someone_won?
      break if board.full?
      clear_screen_and_display_board if human_turn?
    end
  end

  def human_turn?
    @current_marker == human.marker
  end

  def current_player_moves
    human_turn? ? human_moves : computer_moves
  end

  def human_moves
    human.choose_square(board)
  end

  def computer_moves
    computer.choose_square(board)
  end

  def toggle_current_marker
    @current_marker = case @current_marker
                      when human.marker
                        computer.marker
                      else
                        human.marker
                      end
  end

  def clear_screen_and_display_board
    clear
    display_board
  end

  def increment_winner_score
    case board.winning_marker
    when human.marker
      increment_human_wins
    when computer.marker
      increment_computer_wins
    end
  end

  def display_results
    display_round_result
    display_score
  end

  def display_round_result
    clear_screen_and_display_board
    case board.winning_marker
    when human.marker
      declare_human_round_winner
    when computer.marker
      declare_computer_round_winner
    else
      puts "It's a tie!"
    end
  end

  def increment_human_wins
    human.wins += 1
  end

  def declare_human_round_winner
    puts "#{human.name} has won the round"
  end

  def increment_computer_wins
    computer.wins += 1
  end

  def declare_computer_round_winner
    puts "#{computer.name} has won the round"
  end

  def display_score
    puts "\nThe score is:"
    puts "#{human.name} has #{human.wins}".rjust(17)
    puts "#{computer.name} has #{computer.wins}".rjust(17)
    puts ""
  end

  def reset_for_new_round
    reset_board
    display_next_round_message
    reset_first_mover
  end

  def display_next_round_message
    puts "New Round\n\n"
  end

  def display_winner
    case game_winner
    when human.name
      puts "Congratulations. You have won the game!"
    else
      puts "#{computer.name} has won the game!\n"
    end
  end

  def game_winner
    return nil if [human.wins, computer.wins].max < 5
    human.wins == 5 ? human.name : computer.name
  end

  def someone_won_game?
    !!game_winner
  end

  def play_next_round?(prompt: "next round")
    answer = ''
    loop do
      puts "Would you like to play #{prompt}? (y/n)"
      answer = gets.chomp.downcase
      break if %w[y n].include?(answer)
      puts "Sorry, that is not a valid answer.\n\n"
    end
    clear
    answer == 'y'
  end

  def play_new_game?
    play_next_round?(prompt: "a new game")
  end

  def clear
    system 'clear' || 'cls'
  end

  def display_new_game_message
    puts "New Game!\n\n"
  end

  def display_goodbye_message
    puts "Thank you for playing Tic Tac Toe. Goodbye"
  end
end

game = TTTgame.new
game.play
