require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'some_random_string' 


INITIAL_BET_AMOUNT = 500
helpers do
  def sum_of_cards(cards)
    arr = cards.map{|x| x[0]}

    total = 0
    arr.each do |x|
      if x == 'Ace'
        total += 11
      elsif x.to_i == 0 
        total += 10
      else
        total += x.to_i
      end
    end

    if total > 21
      arr.count('Ace').times do 
        total -= 10
      end
    end
    total
  end

  def display_cards(card)
    value = card[0]
    if ['Jack', 'Queen', 'King', 'Ace'].include?(value) 
      value = case card[0]
        when 'Jack' then 'jack'
        when 'Queen' then 'queen'
        when 'King' then 'king'
        when 'Ace' then 'ace'
      end
    elsif 
      card[0]
    end

    suit = case card[1]
      when 'of Hearts' then 'hearts'
      when 'of Spades' then 'spades'
      when 'of Diamonds' then 'diamonds'
      when 'of Clubs' then 'clubs'
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def player_win_or_bust(player_total)
    if player_total == 21
      win!("You've hit blackjack!")
      # start over?
    elsif player_total > 21
      lose!("Looks like you've busted!")
      # start over?
    end
  end

  def win!(message)
    @play_again = true
    session[:player_pot] = session[:player_pot] + session[:player_bet]
    @win = "<strong>#{session[:player_name]}  wins! Congrats!</strong>#{message}. You now have $#{session[:player_pot]}."
  end

  def lose!(message)
    @play_again = true
    session[:player_pot] = session[:player_pot] - session[:player_bet]
    @lose = "<strong>#{session[:player_name]} lost! Sorry!</strong>#{message}. You now have $#{session[:player_pot]}."
  end

  def tie!(message)
    @play_again = true
    @win = "<strong>It's a tie! Congrats!</strong>#{message}. You now have $#{session[:player_pot]}."
  end
end

before do 
  @show_hit_stay_buttons = true
  @show_dealer_button = false
  @play_again = false
end

get '/' do
  if session[:player_name]
    redirect '/bet'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_pot] = INITIAL_BET_AMOUNT 
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Please enter your name."
    halt erb(:new_player)
  end
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do 
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "Please make a bet."
    halt erb :bet 
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "Bet amount cannot be greater than what you have (#{session[:player_pot]})"
  else 
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end 
end

get '/game' do 
  # create deck and put in session 
  suits = ['of Hearts', 'of Spades', 'of Diamonds', 'of Clubs']
  cards = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace']
  session[:deck] = cards.product(suits).shuffle!
  session[:turn] = session[:player_name]
  # deal cards
  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop

  player_total = sum_of_cards(session[:player_cards])
  player_win_or_bust(player_total)

  erb :game
end

post '/game/player/hit' do  
  session[:player_cards] << session[:deck].pop

  player_total = sum_of_cards(session[:player_cards])  
  player_win_or_bust(player_total)

  erb :game, layout: false
end

post '/game/player/stay' do 
  @success = "You have chosen to stay."
  @show_hit_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = 'dealer'
  player_total = sum_of_cards(session[:player_cards])
  dealer_total = sum_of_cards(session[:dealer_cards]) 
  if dealer_total == 21
    lose!("Sorry, dealer's hit blackjack. Dealer wins.")
    @show_hit_stay_buttons = false 
  elsif dealer_total > 21
    win!("Dealer's busted! You win!")
    @show_hit_stay_buttons = false 
  elsif dealer_total >= 17 && dealer_total < 21
    @show_hit_stay_buttons = false 
    redirect '/game/compare'
  else dealer_total < 17
    @show_dealer_button = true
    @show_hit_stay_buttons = false 
  end 
  @show_hit_stay_buttons = false
  erb :game, layout: false
end

post '/game/dealer/hit' do 
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do 
  player_total = sum_of_cards(session[:player_cards])
  dealer_total = sum_of_cards(session[:dealer_cards]) 

  if player_total < dealer_total
    lose!("Your hand is: #{player_total}. Dealers hand is: #{dealer_total}.")
  elsif player_total > dealer_total
    win!("Your hand is: #{player_total}. Dealers hand is: #{dealer_total}.")
  else 
    tie!("Your hand is: #{player_total}. Dealers hand is: #{dealer_total}.")
  end

  erb :game, layout: false
end

get '/game_over' do 
  erb :game_over
end




