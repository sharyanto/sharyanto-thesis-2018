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

-- this is trades which have excluded bots and special transactions. the columns
-- are the same as Trade, but with some extra columns that contain statistics

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

    -- since we do not know the beginning balance before 2011-04-01, and the
    -- transfer data (withdraw/deposit of bitcoins) from Mt Gox leaked database
    -- dump also doesn't contain data for all users involved in trading, the
    -- below balance and gain/loss only concern with bitcoins bought/sold on Mt
    -- Gox in the period of 2011-04 to 2013-11, and the fiat money produced from
    -- selling those bitcoins.

    Balance_Bitcoins DOUBLE NOT NULL,     -- current inventory of bitcoins after this transaction.

    -- note that when there is overselling, we assume the excess to be amount of
    -- bitcoins purchased before 2011-04 or deposited from other exchanges and
    -- ignored that amount. balance will be set to 0 instead of negative. this
    -- also means this balance_bitcoins does not include amount from before
    -- 2011-04 or transferred from other exchanges, because we don't have data
    -- for those.

    Balance_Bitcoins_Book_Value   DOUBLE, -- worth of running balance of bitcoins, in JPY, in terms of bitcoin purchase price. NULL if negative balance.
    Balance_Bitcoins_Market_Value DOUBLE, -- worth of running balance of bitcoins, in JPY, in terms of current bitcoin price. NULL if negative balance.
    Avg_Purchase_Price DOUBLE,            -- NULL if zero or negative balance.
    Paper_Gain DOUBLE,                    -- calculated as Balance_Bitcoins_Market_Value - Balance_Bitcoins_Book_Value. NULL if negative balance.

    Balance_Jpy DOUBLE NOT NULL,          -- running balance of fiat after this transaction (in JPY, since Mt Gox already keeps fiat amount in JPY).

    Bitcoins_Sold DOUBLE NOT NULL,        -- (only when type=sell) bitcoins sold, which is the same as Bitcoins unless when overselling where this will be only be the amount of balance available previous to this transaction.
    Tx_Realized_Gain DOUBLE,              -- (only when type=sell) gain realized in this transaction (in JPY), = Bitcoins * (Average_Purchase_Price). can be negative or NULL when type!=sell or Avg_Purchase_Price is NULL.
    Total_Realized_Gain DOUBLE            -- running total of Tx_Realized_Gain

) ENGINE='MyISAM';

INSERT INTO _Trade2
  SELECT *, 0, NULL, NULL, NULL, NULL, 0, NULL, NULL
  FROM Trade WHERE `Index` NOT IN (SELECT `Index` FROM _Index_Exclude);

CREATE INDEX _Trade2_Stamp        ON _Trade2(Stamp);
CREATE INDEX _Trade2_Index        ON _Trade2(`Index`);
CREATE INDEX _Trade2_User__       ON _Trade2(User__);

CREATE INDEX Price_Stamp ON Price(Stamp);

-- list of unique User__ values in trade data
CREATE TABLE _Trade_User (
    User__ CHAR(36) NOT NULL PRIMARY KEY
);
INSERT INTO _Trade_User SELECT DISTINCT User__ FROM Trade;

-- list of unique index values in trade data
CREATE TABLE _Trade_Index (
    `Index` INT NOT NULL PRIMARY KEY
);
INSERT INTO _Trade_Index SELECT DISTINCT `Index` FROM Trade;

---

CREATE TABLE _Trade2_By_Index (
  `Index` INT NOT NULL,
  First_Trade_Stamp DATETIME,
  First_Buy_Stamp DATETIME,
  First_Sell_Stamp DATETIME,
  Last_Trade_Stamp DATETIME,
  Last_Buy_Stamp DATETIME,
  Last_Sell_Stamp DATETIME,
  Num_Trades INT NOT NULL,
  Num_Buys INT NOT NULL,
  Num_Sells INT NOT NULL,
  Trade_Volume_Bitcoins DOUBLE NOT NULL,
  Buy_Volume_Bitcoins DOUBLE NOT NULL,
  Sell_Volume_Bitcoins DOUBLE NOT NULL,
  Trade_Volume_Jpy DOUBLE NOT NULL,
  Buy_Volume_Jpy DOUBLE NOT NULL,
  Sell_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Index
  SELECT
    `Index`,
    MIN(Stamp),
    MIN(IF(Type='buy',Stamp,NULL)),
    MIN(IF(Type='sell',Stamp,NULL)),
    MAX(Stamp),
    MAX(IF(Type='buy',Stamp,NULL)),
    MAX(IF(Type='sell',Stamp,NULL)),
    COUNT(*),
    SUM(IF(Type='buy',1,0)),
    SUM(IF(Type='sell',1,0)),
    SUM(Bitcoins),
    SUM(IF(Type='buy',Bitcoins,0)),
    SUM(IF(Type='sell',Bitcoins,0)),
    SUM(Money_Jpy),
    SUM(IF(Type='buy',Money_Jpy,0)),
    SUM(IF(Type='sell',Money_Jpy,0))
  FROM _Trade2 GROUP BY `Index`;

CREATE UNIQUE INDEX _Trade2_By_Index_Index      ON _Trade2_By_Index(`Index`);
CREATE INDEX _Trade2_By_Index_First_Trade_Stamp ON _Trade2_By_Index(First_Trade_Stamp);
CREATE INDEX _Trade2_By_Index_Last_Trade_Stamp  ON _Trade2_By_Index(Last_Trade_Stamp);
CREATE INDEX _Trade2_By_Index_First_Buy_Stamp   ON _Trade2_By_Index(First_Buy_Stamp);
CREATE INDEX _Trade2_By_Index_Last_Buy_Stamp    ON _Trade2_By_Index(Last_Buy_Stamp);
CREATE INDEX _Trade2_By_Index_First_Sell_Stamp  ON _Trade2_By_Index(First_Sell_Stamp);
CREATE INDEX _Trade2_By_Index_Last_Sell_Stamp   ON _Trade2_By_Index(Last_Sell_Stamp);

---

CREATE TABLE _Trade2_By_Currency (
  Currency__ CHAR(3) NOT NULL,
  Num_Buys INT NOT NULL,
  Num_Sells INT NOT NULL,
  Buy_Volume_Bitcoins DOUBLE NOT NULL,
  Sell_Volume_Bitcoins DOUBLE NOT NULL,
  Buy_Volume_Jpy DOUBLE NOT NULL,
  Sell_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Currency
  SELECT
    Currency__,
    SUM(IF(Type='buy',1,0)),
    SUM(IF(Type='sell',1,0)),
    SUM(IF(Type='buy',Bitcoins,0)),
    SUM(IF(Type='sell',Bitcoins,0)),
    SUM(IF(Type='buy',Money_Jpy,0)),
    SUM(IF(Type='sell',Money_Jpy,0))
  FROM _Trade2 GROUP BY Currency__;

---

CREATE TABLE _Index_With_Duplicate_Users_In_Trade (
  `Index` INT NOT NULL,
  User__ CHAR(36) NOT NULL
);
INSERT INTO _Index_With_Duplicate_Users_In_Trade
  SELECT DISTINCT `Index`, User__ FROM Trade WHERE User__<>'' AND `Index` IN (
    SELECT `Index` from Trade WHERE User__<>'' GROUP BY `Index` HAVING COUNT(DISTINCT User__) > 1
  );

---

CREATE TABLE _Period (
  Name VARCHAR(32) NOT NULL PRIMARY KEY,
  Begin_Stamp DATETIME NOT NULL,
  End_Stamp   DATETIME NOT NULL
);
INSERT INTO _Period VALUES ('bull1', '2011-04-01 00:28:54', '2011-06-08 23:59:59');
INSERT INTO _Period VALUES ('bear1', '2011-06-09 00:00:00', '2011-11-19 23:59:59');
INSERT INTO _Period VALUES ('bull2', '2011-11-20 00:00:00', '2013-11-30 23:59:55');
