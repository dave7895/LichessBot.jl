function chooseMove(b::Chess.Board; variant = "standard")
    @debug("choosing move", b)
    move = search_in_opening_books(b; variant = variant)
    if !isnothing(move)
        @debug("returning bookmove")
        return move
    end
    @debug("no move found in book")
    myColor = sidetomove(b)
    possible = moves(b)

    if !isempty(possible)
        freeRealEstate = attacked_but_undefended(b, -myColor)
        anyFree = !isempty(freeRealEstate)
        @debug("freeRealEstate: ")
        pprint(b, highlight = freeRealEstate)
        takeable = attacked_with_pieces(b, -myColor)
        anyTakeable = !isempty(takeable)
        @debug("takeable squares/pieces")
        pprint(b, highlight = takeable)
        takingFree = Move[]
        takingAny = Move[]
        @debug("$(length(possible)) moves to evaluate")
        mCounter = 0
        bestPawnEval = 0
        bestPawnEvalFor = nothing
        @debug("starting loop")
        for m in possible
            @debug("start of iteration")
            undo = domove!(b, m)
            @debug("did move, undo information saved")
            if ischeckmate(b)
                @debug("found checkmate")
                undomove!(b, undo)
                return m
            end
            @debug("checked for amte")
            if any(mov -> move_is_mate(b, mov), moves(b))
                @debug("skipping move to not get mated in 1")
                undomove!(b, undo)
                continue
            end
            @debug("checked for incoming mate")
            if isstalemate(b)
                @debug("skipping move to avoid stalemating")
                undomove!(b, undo)
                continue
            end
            pE = pawnEval(b, myColor)
            @debug("pawnEval done")
            if pE > bestPawnEval
                bestPawnEval = pE
                bestPawnEvalFor = m
            end
            undomove!(b, undo)
            if anyFree && to(m) in freeRealEstate
                @debug("found move that takes unprotected")
                @show takingFree
                @debug(typeof(m))
                push!(takingFree, m)
                @debug(takingFree)
                #return m
            elseif anyTakeable && to(m) in takeable
                takingValue = value(pieceon(b, from(m)))
                takenValue = value(pieceon(b, to(m)))
                @show takingValue
                @show takenValue
                if takingValue <= takenValue
                    @debug("found move that takes higher valued but protected")
                    push!(takingAny, m)
                end
            end
            mCounter += 1
            @debug("\r", mCounter, "/", length(possible), " evaluated")
        end
        @show takingAny
        @show takingFree
        if !isempty(takingFree)
            @debug("returning random take of unprotected")
            return rand(takingFree)
        end
        if !isempty(takingAny)
            @debug("returning random move that takes higher valued")
            return rand(takingAny)
        end
        if !isnothing(bestPawnEvalFor)
            return bestPawnEvalFor
        end
        @debug("returning completely random move")
        return rand(possible)
        if !isempty(takingAny)
            @debug("returning random move that takes higher valued")
            return rand(takingAny)
        end
        @debug("returning completely random move, no mate no free")
        return rand(possible)
    end
    move
end

function attacked_but_undefended(board, color)
    # copied from Chess.jl tutorial at https://romstad.github.io/Chess.jl/stable/manual/#Square-Sets-1

    attacker = -color  # The opposite color

    # Find all attacked squares
    attacked = SS_EMPTY  # The empty square set
    for s ∈ pieces(board, attacker)
        attacked = attacked ∪ attacksfrom(board, s)
    end

    # Find all defended squares
    defended = SS_EMPTY
    for s ∈ pieces(board, color)
        defended = defended ∪ attacksfrom(board, s)
    end

    # Return all attacked, but undefended squares containing pieces of
    # the desired color:
    attacked ∩ -defended ∩ pieces(board, color)
end

function attacked_with_pieces(board, color)
    attacker = -color
    attacked = SS_EMPTY
    for s ∈ pieces(board, attacker)
        attacked = attacked ∪ attacksfrom(board, s)
    end

    attacked ∩ pieces(board, color)
end


function move_is_mate(board, move)
    #from CHess.jl Tutorial
    # Do the move
    u = domove!(board, move)

    # Check if the resulting board is checkmate
    result = ischeckmate(board)

    # Undo the move
    undomove!(board, u)

    # Return result
    result
end

function value(p::Chess.Piece)
    p == PIECE_TYPE_NONE && return -1
    return ptype(p).val
end

function search_in_opening_books(b; variant = "standard")
    if variant == "atomic"
        move = pickbookmove(
            b,
            bookfile = "/home/dave/LichessGames/atomicOpening.obk",
        )
    else
        move = pickbookmove(
            b,
            bookfile = "/home/dave/LichessGames/lichess_elite.obk",
        )
        if isnothing(move)
            @debug("no move found in elite db, looking in own games")
            move = pickbookmove(
                b,
                bookfile = "/home/dave/LichessGames/myGames.obk",
            )
        end
    end
    return move
end

function pawnEval(b::Board, c::PieceColor, m::Union{Move,Nothing} = nothing)
    undo = nothing
    homerank = c == WHITE ? RANK_1 : RANK_8
    if !isnothing(m)
        undo = domove!(b, m)
    end
    myPawns = pawns(b, c)
    isempty(myPawns) && return 0
    isnothing(undo) || undomove!(b, undo)
    sum(square -> distance(homerank, rank(square))^2, myPawns)
end
