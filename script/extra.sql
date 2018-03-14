-- this SQL file should be executed after importing, to add indices and
-- statistics tables.

-- make sure User__ are unique

CREATE UNIQUE INDEX User_Wallet_User__Currency__ ON User_Wallet(User__,Currency__);

-- add some indices to Trade table to speed up queries. adding each of the index
-- below takes about 2-6 minutes on my Asus Zenbook UX305 (Intel Core M-Y571 1.2
-- GHz) laptop.

CREATE INDEX Trade_Stamp        ON Trade(Stamp);
CREATE INDEX Trade_Index        ON Trade(`Index`);
CREATE INDEX Trade_User__       ON Trade(User__);

-- this is a list of user Index we want to ignore in this study, because they
-- are special users

CREATE TABLE _Index_Exclude (
    `Index` INT NOT NULL PRIMARY KEY,
    Note VARCHAR(255)
) ENGINE='MyISAM';

INSERT INTO _Index_Exclude VALUES (-1, 'deleted');
INSERT INTO _Index_Exclude VALUES (-2, 'THK');
-- in the Willy Report, it is pointed out that trades with User_Country='??' and
-- User_State='??' are those initiated by bots
INSERT INTO _Index_Exclude (`Index`,Note) SELECT DISTINCT `Index`, 'bot'  FROM Trade WHERE User_Country='??' AND User_State='??';

-- this is trades which have excluded bots and special transactions

CREATE TABLE _Trade2 (
    _rowid INT NOT NULL PRIMARY KEY,
    Id BIGINT NOT NULL,              -- [ 0]
    Stamp DATETIME,                  -- [ 1]
    `Index` INT NOT NULL,            -- [ 2] only in format=2
    User__ CHAR(36),                 -- [ 3] only in format=2
    User_Id_Hash CHAR(36),           -- [ 4]
    Japan CHAR(3) NOT NULL,          -- [ 5]
    Type VARCHAR(4) NOT NULL,        -- [ 6]
    Currency__ CHAR(3) NOT NULL,     -- [ 7]
    Bitcoins DOUBLE NOT NULL,        -- [ 8] amount of bitcoins
    Money DOUBLE NOT NULL,           -- [ 9] amount of money in Currency__
    Money_Rate DOUBLE NOT NULL,      -- [10] exchange rate of Currency__ (e.g.  'USD', or 'EUR') against JPY
    Money_Jpy DOUBLE NOT NULL,       -- [11] amount of money in JPY, = Money * Money_Rate
    Money_Fee DOUBLE NOT NULL,       -- [12] fees in fiat currency (only when type='sell')
    Money_Fee_Rate DOUBLE NOT NULL,  -- [13] like Money_Rate, in Currency__
    Money_Fee_Jpy DOUBLE NOT NULL,   -- [14] = Money_Fee x Money_Fee_Rate
    Bitcoin_Fee DOUBLE NOT NULL,     -- [15] fees in bitcoins (only when type=buy)
    Bitcoin_Fee_Jpy DOUBLE NOT NULL, -- [16] fess in bitcoins in JPY
    User_Country CHAR(2),            -- [17]
    User_State CHAR(2),              -- [18]

    -- the below columns are for testing/experimenting. since we do not know the
    -- beginning balance, the available data for deposits (and withdraws) are
    -- also from ~2011-04-01 (mtgox operates since jul 2010). thus we cannot
    -- reliably say that a user is currently in paper gain/loss position (except
    -- for the bitcoins that he bought in the period of 2011-04 or later) or
    -- whether he is realizing gain/loss (except, again. for the bitcoins that
    -- he bought in the period of 2011-04).

    Balance_Bitcoins DOUBLE NOT NULL,-- running balance of bitcoins after this transaction
    Balance_Jpy DOUBLE NOT NULL,     -- running balance of fiat after this transaction (in JPY, since Mt Gox already keeps fiat amount in JPY)
    Avg_Purchase_Price DOUBLE,       -- current average purchase price (in JPY), NULL if zero/negative bitcoin balance
    Paper_Gain DOUBLE,               -- running paper gain (in JPY), = Balance_Bitcoins * (current_BTC_price in JPY - Avg_Purchase_Price). can be negative or NULL when Avg_Purchase_Price is NULL.
    Tx_Realized_Gain DOUBLE,         -- (only when type=sell) gain realized in this transaction (in JPY), = Bitcoins * (). can be negative or NULL when type!=sell or Avg_Purchase_Price is NULL.
    Total_Realized_Gain DOUBLE       -- running total of Tx_Realized_Gain

) ENGINE='MyISAM';

INSERT INTO _Trade2 SELECT * FROM Trade WHERE `Index` NOT IN (SELECT `Index` FROM _Index_Exclude);

CREATE INDEX _Trade2_Stamp        ON _Trade2(Stamp);
CREATE INDEX _Trade2_Index        ON _Trade2(`Index`);
CREATE INDEX _Trade2_User__       ON _Trade2(User__);

CREATE INDEX Price_Stamp ON Price(Stamp);

-- list of unique User__ values in trade data
CREATE TABLE _Trade_Users (
    User__ CHAR(36) NOT NULL PRIMARY KEY
);
INSERT INTO _Trade_Users SELECT DISTINCT User__ FROM Trade;

-- list of unique index values in trade data
CREATE TABLE _Trade_Indexes (
    `Index` INT NOT NULL PRIMARY KEY
);
INSERT INTO _Trade_Indexes SELECT DISTINCT `Index` FROM Trade;

---

CREATE TABLE _Trade2_By_Currency (
  Currency__ CHAR(3) NOT NULL,
  Count INT NOT NULL
);
INSERT INTO _Trade2_By_Currency (`Index`,Note) SELECT DISTINCT `Index`, 'bot'  FROM Trade WHERE User_Country='??' AND User_State='??';

---

CREATE TABLE _Index_With_Duplicate_Users_In_Trade (
  `Index` INT NOT NULL,
  User__ CHAR(36) NOT NULL
);
INSERT INTO _Index_With_Duplicate_Users_In_Trade
  SELECT DISTINCT `Index`, User__ FROM Trade WHERE User__<>'' AND `Index` IN (
    SELECT `Index` from Trade WHERE User__<>'' GROUP BY `Index` HAVING COUNT(DISTINCT User__) > 1
  );
