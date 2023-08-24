module TidalTycoon::TTE {
    use sui::transfer::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::{Self, SUI};
    use sui::object::{Self, UID};

    // Error codes
    const EIncorrectPlayer: u64 = 201;
    const EGameNotFinished: u64 = 202;
    const EPlayerNotConfirmed: u64 = 203;
    const EInsufficientFund: u64 = 204;


    struct TTE has drop {}  // TidalTycoon Engine OTW

    struct TTGS has key {  // TidalTycoon Game State Object
        // Player list
        players: vector<address>,  // a size4 list containing player addresses
        players_confirmed: vector<bool>,  // a size4 list containing whether each player has confirmed their attendance


        // Player data
        player_positions: vector<u8>,  // a size4 list containing each player's position, value 0-39
        player_balances: vector<u256>,  // a size4 list containing each player's current in-game balance
        player_properties: vector<vector<u8>>,  // a size4 list containing each player's list of owned properties

        // Game global constants
        game_id: UID,
        game_length: u8,  // number of turns per player
        prize_pool: Coin<SUI>,  // amount of money pooled from the players to be award to the winner
        entry_fee: u256,  // entry fee (Sui tokens) needed to play the game

        // Game global variables
        game_in_progress: bool,  // did the game start?
        current_player: u8,
        current_turn: u8,
    }

    public fun new_game(players: vector<address>,
                        game_length: u8,
                        min_entry_fee: u256,

                        ctx: &mut TxContext): address {
        let id: UID = object::new(ctx);
        // Create a new game state
        let gs = TTGS {
            players,
            players_confirmed: vector[false, false, false, false],

            player_positions: x"00000000", // hex trick to create a size4 list of 0s
            player_balances: vector[1500, 1500, 1500, 1500],
            player_properties: vector[vector[], vector[], vector[], vector[]],

            game_id: id,
            game_length,
            prize_pool: 0,
            entry_fee,
            game_in_progress: false,
            current_player: 0,
            current_turn: 0,
        };

        transfer::share_object(gs);
        id  // return the game object unique id
    }

    public fun join_game(gs: TTGS, player: address, position: u8, entry_fee: Coin<SUI>, ctx: &mut TxContext) {
        assert!(gs.players[position] == player, EIncorrectPlayer);
        assert!(gs.entry_fee == coin::value(entry_fee), EInsufficientFund);
        coin::join(gs.prize_pool, entry_fee);  // add entry fee to pool
        gs.players_confirmed[position] = true;  // confirm player attendance
    }

    public fun end_game(gs: TTGS, ctx: &mut TxContext) {
        assert!(gs.current_turn >= gs.game_length, EGameNotFinished);
        // find the index of the player with the largest balance
        let winner: u8 = 0;
        let max_balance: u256 = gs.player_balances[0];

        let i = 1;
        while (i < 4) {
            if (gs.player_balances[i] > max_balance) {
                winner = i;
                max_balance = gs.player_balances[i];
            };
            i = i + 1;
        };

        // transfer the prize pool to the winner
        transfer::public_transfer(gs.prize_pool, gs.players[winner]);

        // delete game object
        object::delete(gs.game_id);
    }

    public fun start_game(gs: TTGS, ctx: &mut TxContext) {
        // Check all players have confirmed their attendance
        assert!(gs.players_confirmed[0] &&
                gs.players_confirmed[1] &&
                gs.players_confirmed[2] &&
                gs.players_confirmed[3], EPlayerNotConfirmed);
        gs.game_in_progress = true;
    }

}
