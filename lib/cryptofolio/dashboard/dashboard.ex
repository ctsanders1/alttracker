defmodule Cryptofolio.Dashboard do
  @moduledoc """
  The boundary for the Dashboard system.
  """

  import Ecto.Query, warn: false
  alias Cryptofolio.Repo

  alias Cryptofolio.Trade, as: TradeService
  alias Cryptofolio.Marketcap
  alias Cryptofolio.Dashboard.Trade
  alias Cryptofolio.Dashboard.Currency
  alias Cryptofolio.Dashboard.CurrencyTick

  def get_portfolio(user) do
    trades = Cryptofolio.Dashboard.list_dashboard_trades_for_user(user)

    %{
      trades: trades,
      total: trades
        |> Enum.map(&TradeService.current_value/1)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2),
      currencies: Enum.map(trades, &(&1.currency))
    }
  end

  def list_dashboard_trades_for_user(user) do
    last_ticks = CurrencyTick
                 |> distinct([t], [t.currency_id])
                 |> order_by([t], [t.currency_id, desc: t.last_updated])

    Trade
    |> where(user_id: ^user.id)
    |> join(:inner, [t], _ in assoc(t, :currency)) 
    |> select([trade, curr], {trade, curr})
    |> Repo.all
    |> Enum.map(&Cryptofolio.Dashboard.add_current_value_assocs/1)
  end

  def add_current_value_assocs({trade, curr}) do
    currency = trade
               |> Ecto.build_assoc(:currency, curr)
               |> Map.put(:cost_usd, Marketcap.get_coin_price(curr.symbol))
               |> Map.drop([:last_tick])

    trade = trade |> Map.put(:currency, currency)

    trade
    |> Map.put(:current_value, Cryptofolio.Trade.current_value(trade))
  end

  def build_trade_assocs({trade, curr, tick}) do
    currency = Ecto.build_assoc(trade, :currency, curr)

    %Trade{ trade | currency: %Currency{ currency | last_tick: tick } }
  end

  @doc """
  Returns the list of trades.

  ## Examples

      iex> list_trades()
      [%Trade{}, ...]

  """
  def list_trades do
    Repo.all(Trade)
  end

  @doc """
  Gets a single trade.

  Raises `Ecto.NoResultsError` if the Trade does not exist.

  ## Examples

      iex> get_trade!(123)
      %Trade{}

      iex> get_trade!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trade!(id), do: Repo.get!(Trade, id)

  @doc """
  Creates a trade.

  ## Examples

      iex> create_trade(%{field: value})
      {:ok, %Trade{}}

      iex> create_trade(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_trade(user, attrs \\ %{}) do
    user
    |> Ecto.build_assoc(:trades)
    |> Trade.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trade.

  ## Examples

      iex> update_trade(trade, %{field: new_value})
      {:ok, %Trade{}}

      iex> update_trade(trade, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trade(%Trade{} = trade, attrs) do
    trade
    |> Trade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Trade.

  ## Examples

      iex> delete_trade(trade)
      {:ok, %Trade{}}

      iex> delete_trade(trade)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trade(%Trade{} = trade) do
    Repo.delete(trade)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trade changes.

  ## Examples

      iex> change_trade(trade)
      %Ecto.Changeset{source: %Trade{}}

  """
  def change_trade(%Trade{} = trade) do
    Trade.changeset(trade, %{})
  end

  def list_currencies do
    Repo.all(Currency)
  end
end
