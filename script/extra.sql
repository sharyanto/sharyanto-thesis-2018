-- this SQL file should be executed after importing, to add indices and
-- statistics tables.

-- subperiods

CREATE TABLE _Period (
  Name VARCHAR(32) NOT NULL PRIMARY KEY,
  Begin_Stamp DATETIME NOT NULL,
  End_Stamp   DATETIME NOT NULL,
  Begin_Day   INT NOT NULL,  -- 0, 1, ...
  End_Day     INT NOT NULL,  -- 0, 1, ...
);
INSERT INTO _Period VALUES ('bull1', '2011-04-01 00:28:54', '2011-06-08 23:59:59', -1, -1);
INSERT INTO _Period VALUES ('bear1', '2011-06-09 00:00:00', '2011-11-19 23:59:59', -1, -1);
INSERT INTO _Period VALUES ('bull2', '2011-11-20 00:00:00', '2013-11-30 23:59:55', -1, -1);
INSERT INTO _Period VALUES ('all'  , '2011-04-01 00:28:54', '2013-11-30 23:59:59', -1, -1);
UPDATE _Period SET
  Begin_Day=FLOOR((UNIX_TIMESTAMP(Begin_Stamp) - 1301616000)/86400),
  End_Day  =FLOOR((UNIX_TIMESTAMP(End_Stamp  ) - 1301616000)/86400);

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

CREATE TABLE _Trade_Index_Exclude (
    `Index` INT NOT NULL PRIMARY KEY,
    Note VARCHAR(255)
) ENGINE='MyISAM';

INSERT INTO _Trade_Index_Exclude VALUES (-1, 'deleted');
INSERT INTO _Trade_Index_Exclude VALUES (-2, 'THK');
-- in the Willy Report, it is pointed out that trades with User_Country='??' and
-- User_State='??' are those initiated by bots
INSERT INTO _Trade_Index_Exclude (`Index`,Note) SELECT DISTINCT `Index`, 'bot'  FROM Trade WHERE User_Country='??' AND User_State='??';
-- also these IDs
INSERT INTO _Trade_Index_Exclude (`Index`,Note) VALUES (634, 'bot');
INSERT INTO _Trade_Index_Exclude (`Index`,Note) VALUES (179200, 'bot');
INSERT INTO _Trade_Index_Exclude (`Index`,Note) VALUES (698630, 'bot'); -- "Markus"
-- also these IDs by us
INSERT INTO _Trade_Index_Exclude (`Index`,Note) VALUES (231, 'bot2'); -- weird pattern, buy+sell lots of 0.01 bitcoins at the same time

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

        -- amount of bitcoins sold/bought. when type=buy, this is Bitcoins -
        -- Bitcoin_Fee. when type=sell, this is negative: -MIN(Bitcoins,
        -- amount-which-cause-balance-to-be-zero). when there is an overselling,
        -- only be the amount up to available balance (in negative sign) will be
        -- used, to avoid negative balance.
    Bitcoins_Change DOUBLE NOT NULL,

        -- current inventory (running balance) of bitcoins after this
        -- transaction, which is Balance_Bitcoins at user's previous transaction
        -- + Bitcoins_Change
    Balance_Bitcoins DOUBLE NOT NULL,

        -- worth of running balance of bitcoins, in JPY, in terms of bitcoin
        -- purchase price. NULL if zero balance.
    Balance_Bitcoins_Book_Value   DOUBLE NOT NULL,
        -- worth of running balance of bitcoins, in JPY, in terms of current
        -- bitcoin price. NULL if zero balance.
    Balance_Bitcoins_Market_Value DOUBLE NOT NULL,
        -- NULL if zero balance.
    Avg_Purchase_Price DOUBLE,
        -- calculated as Balance_Bitcoins_Market_Value -
        -- Balance_Bitcoins_Book_Value. NULL if negative balance.
    Paper_Gain DOUBLE,
        -- running balance of fiat after this transaction (in JPY, since Mt Gox
        -- already keeps fiat amount in JPY).
    Balance_Jpy DOUBLE NOT NULL,
        -- (only when type=sell) gain realized in this transaction (in JPY), =
        -- Bitcoins * (Average_Purchase_Price). can be negative or NULL when
        -- type!=sell or Avg_Purchase_Price is NULL.
    Tx_Realized_Gain DOUBLE,
        -- running total of Tx_Realized_Gain
    Total_Realized_Gain DOUBLE,
) ENGINE='MyISAM';

INSERT INTO _Trade2
  SELECT *, 0, NULL, NULL, NULL, NULL, 0, NULL, NULL
  FROM Trade WHERE `Index` NOT IN (SELECT `Index` FROM _Trade_Index_Exclude);

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

CREATE TABLE _Trade2_By_Index_Period (
  `Index` INT NOT NULL,
  Period VARCHAR(32) NOT NULL,
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
INSERT INTO _Trade2_By_Index_Period
  SELECT
    t.`Index` `Index`, p.Name Period,
    MIN(t.Stamp),
    MIN(IF(t.Type='buy',t.Stamp,NULL)),
    MIN(IF(t.Type='sell',t.Stamp,NULL)),
    MAX(t.Stamp),
    MAX(IF(t.Type='buy',t.Stamp,NULL)),
    MAX(IF(t.Type='sell',t.Stamp,NULL)),
    COUNT(*),
    SUM(IF(t.Type='buy',1,0)),
    SUM(IF(t.Type='sell',1,0)),
    SUM(t.Bitcoins),
    SUM(IF(t.Type='buy',t.Bitcoins,0)),
    SUM(IF(t.Type='sell',t.Bitcoins,0)),
    SUM(t.Money_Jpy),
    SUM(IF(t.Type='buy',t.Money_Jpy,0)),
    SUM(IF(t.Type='sell',t.Money_Jpy,0))
  FROM _Trade2 t
  JOIN _Period p
  WHERE t.Stamp BETWEEN p.Begin_Stamp AND p.End_Stamp
  GROUP BY `Index`,Period;

CREATE UNIQUE INDEX _Trade2_By_Index_Period_Index_Period      ON _Trade2_By_Index_Period(`Index`,Period);
CREATE INDEX _Trade2_By_Index_Period_First_Trade_Stamp ON _Trade2_By_Index_Period(First_Trade_Stamp);
CREATE INDEX _Trade2_By_Index_Period_Last_Trade_Stamp  ON _Trade2_By_Index_Period(Last_Trade_Stamp);
CREATE INDEX _Trade2_By_Index_Period_First_Buy_Stamp   ON _Trade2_By_Index_Period(First_Buy_Stamp);
CREATE INDEX _Trade2_By_Index_Period_Last_Buy_Stamp    ON _Trade2_By_Index_Period(Last_Buy_Stamp);
CREATE INDEX _Trade2_By_Index_Period_First_Sell_Stamp  ON _Trade2_By_Index_Period(First_Sell_Stamp);
CREATE INDEX _Trade2_By_Index_Period_Last_Sell_Stamp   ON _Trade2_By_Index_Period(Last_Sell_Stamp);

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

CREATE TABLE _Trade_Index_With_Duplicate_Users_In_Trade (
  `Index` INT NOT NULL,
  User__ CHAR(36) NOT NULL
);
INSERT INTO _Trade_Index_With_Duplicate_Users_In_Trade
  SELECT DISTINCT `Index`, User__ FROM Trade WHERE User__<>'' AND `Index` IN (
    SELECT `Index` from Trade WHERE User__<>'' GROUP BY `Index` HAVING COUNT(DISTINCT User__) > 1
  );

---

-- note: this only shows trading volume vs time, not returns

CREATE TABLE _Trade2_By_Hour_Of_Day (
  `Hour` INT NOT NULL,
  Num_Trades INT NOT NULL,
  Trade_Volume_Bitcoins DOUBLE NOT NULL,
  Trade_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Hour_Of_Day
  SELECT
    HOUR(Stamp) `Hour`,
    COUNT(*) Num_Trades,
    SUM(Bitcoins) Trade_Volume_Bitcoins,
    SUM(Money_Jpy) Trade_Volume_Jpy
  FROM _Trade2
  GROUP BY HOUR(Stamp);

---

CREATE TABLE _Trade2_By_Day_Of_Week (
  `Dow` INT NOT NULL, -- 1 = sunday, 7 = saturday
  Num_Trades INT NOT NULL,
  Trade_Volume_Bitcoins DOUBLE NOT NULL,
  Trade_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Day_Of_Week
  SELECT
    DAYOFWEEK(Stamp) `Dow`,
    COUNT(*) Num_Trades,
    SUM(Bitcoins) Trade_Volume_Bitcoins,
    SUM(Money_Jpy) Trade_Volume_Jpy
  FROM _Trade2
  GROUP BY DAYOFWEEK(Stamp);

---

CREATE TABLE _Trade2_By_Day_Of_Month (
  `Day` INT NOT NULL,
  Num_Trades INT NOT NULL,
  Trade_Volume_Bitcoins DOUBLE NOT NULL,
  Trade_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Day_Of_Month
  SELECT
    DAY(Stamp) `Day`,
    COUNT(*) Num_Trades,
    SUM(Bitcoins) Trade_Volume_Bitcoins,
    SUM(Money_Jpy) Trade_Volume_Jpy
  FROM _Trade2
  GROUP BY DAY(Stamp);

---

CREATE TABLE _Trade2_By_Country (
  User_Country CHAR(2),
  Num_Trades INT NOT NULL,
  Num_Traders INT NOT NULL,
  Trade_Volume_Bitcoins DOUBLE NOT NULL,
  Trade_Volume_Jpy DOUBLE NOT NULL
);
INSERT INTO _Trade2_By_Country
  SELECT
    User_Country,
    COUNT(*) Num_Trades,
    COUNT(Distinct `Index`) Num_Traders,
    SUM(Bitcoins) Trade_Volume_Bitcoins,
    SUM(Money_Jpy) Trade_Volume_Jpy
  FROM _Trade2
  GROUP BY User_Country;

---

-- this lists traders who are only identified by a single User_Country value

CREATE TABLE _Trade2_Index_Country (
  `Index` INT NOT NULL PRIMARY KEY,
  User_Country CHAR(2) NOT NULL
);
INSERT INTO _Trade2_Index_Country
  SELECT
    `Index`,
    GROUP_CONCAT(DISTINCT User_Country)
  FROM _Trade2
  WHERE User_Country IS NOT NULL AND User_Country <> '' AND User_Country <> '!!'
  GROUP BY `Index`
  HAVING COUNT(DISTINCT User_Country) = 1;

---

CREATE INDEX Transfer_Wallet ON Transfer(Wallet);
CREATE INDEX Transfer_Entry ON Transfer(Entry); -- there are duplicate values
CREATE INDEX Transfer_Date ON Transfer(Date);

--- list of User Indexes in Trade that are associated with only a single User__ value

CREATE TABLE _Trade_Index_With_Single_User (
  `Index` INT NOT NULL,
  `User__` CHAR(36) NOT NULL
);
INSERT INTO _Trade_Index_Always_With_User
  SELECT `Index`, GROUP_CONCAT(DISTINCT `User__`) FROM Trade
  WHERE User__ IS NOT NULL AND User__<>'' GROUP BY `Index` HAVING COUNT(DISTINCT User__)=1;

-- daily average price from transaction data (prices are all in Jpy). 1301616000
-- is epoch for '2014-04-01 00:00:00 UTC'.
CREATE TABLE _Daily_Price_From_Trade2 (
  Day INT NOT NULL PRIMARY KEY, -- day after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp_Unix), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp),
  Highest DOUBLE NOT NULL, -- highest price of the day
  Lowest  DOUBLE NOT NULL, -- lowest price of the day

  -- simple average of pricing, but what's more appropriate to use is the value
  -- (in-fiat) weighted average, because small bitcoin trade (e.g. 1 satoshi)
  -- are often of extreme prices)
  Average_Simple DOUBLE NOT NULL, -- simple average price of the day

  Average_Weighted DOUBLE NOT NULL, -- value-weighted average price of the day

  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Daily_Price_From_Trade2
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) Day,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)) AS Begin_Stamp,
    MAX(Money_Jpy/Bitcoins) Highest,
    MIN(Money_Jpy/Bitcoins) Lowest,
    AVG(Money_Jpy/Bitcoins) Average_Simple,
    SUM(Money_Jpy)/SUM(Bitcoins) Average_Weighted,
    COUNT(*) Num
  FROM _Trade2
  WHERE Bitcoins > 0
  GROUP BY Day;

-- daily average price from Price table (JPY). the price data for JPY is
-- sometimes missing for the date that we want.
CREATE TABLE _Daily_Price_From_Price_Jpy (
  Day INT NOT NULL PRIMARY KEY, -- day after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp_Unix),
  Highest DOUBLE NOT NULL, -- highest price of the day
  Lowest  DOUBLE NOT NULL, -- lowest price of the day
  Average_Simple DOUBLE NOT NULL, -- simple average price of the day
  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Daily_Price_From_Price_Jpy
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) Day,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)) AS Begin_Stamp,
    MAX(Price) Highest,
    MIN(Price) Lowest,
    AVG(Price) Average_Simple,
    COUNT(*) Num
  FROM Price
  WHERE Currency__='JPY'
  GROUP BY Day;

-- daily average price from Price table (USD but converted to JPY). the price
-- data for USD the most abundant
CREATE TABLE _Daily_Price_From_Price_Usd (
  Day INT NOT NULL PRIMARY KEY, -- day after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp_Unix), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp),
  Highest DOUBLE NOT NULL, -- highest price of the day
  Lowest  DOUBLE NOT NULL, -- lowest price of the day
  Average_Simple DOUBLE NOT NULL, -- simple average price of the day
  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Daily_Price_From_Price_Usd
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) Day,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400) * 86400)) AS Begin_Stamp,
    MAX(Price) Highest,
    MIN(Price) Lowest,
    AVG(Price) Average_Simple,
    COUNT(*) Num
  FROM Price
  WHERE Currency__='USD'
  GROUP BY Day;
-- convert USD prices to JPY
UPDATE _Daily_Price_From_Price_Usd t1 SET
  Highest       =Highest       *(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1),
  Lowest        =Lowest        *(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1),
  Average_Simple=Average_Simple*(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1)
  ;

-- daily average price change. see also: _Daily_Return table.
CREATE TABLE _Daily_Price_Change (
  Day INT NOT NULL PRIMARY KEY,
  Percent_Change DOUBLE
);
INSERT INTO _Daily_Price_Change
  SELECT
    Day,
    (Average-(SELECT Average FROM _Daily_Price WHERE Day=p1.Day-1))/(SELECT Average FROM _Daily_Price WHERE Day=p1.Day-1)*100 `Percent_Change`
  FROM _Daily_Price p1;

-- weekly average price from transaction data (prices are all in Jpy).
-- 1301616000 is epoch for '2014-04-01 00:00:00 UTC'.
CREATE TABLE _Weekly_Price_From_Trade2 (
  Week INT NOT NULL PRIMARY KEY, -- week after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp_Unix), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp),
  Highest DOUBLE NOT NULL, -- highest price of the day
  Lowest  DOUBLE NOT NULL, -- lowest price of the day

  -- simple average of pricing, but what's more appropriate to use is the value
  -- (in-fiat) weighted average, because small bitcoin trade (e.g. 1 satoshi)
  -- are often of extreme prices)
  Average_Simple DOUBLE NOT NULL, -- simple average price of the week

  Average_Weighted DOUBLE NOT NULL, -- value-weighted average price of the week

  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Weekly_Price_From_Trade2
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) Week,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400*7)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400*7)) AS Begin_Stamp,
    MAX(Money_Jpy/Bitcoins) Highest,
    MIN(Money_Jpy/Bitcoins) Lowest,
    AVG(Money_Jpy/Bitcoins) Average_Simple,
    SUM(Money_Jpy)/SUM(Bitcoins) Average_Weighted,
    COUNT(*) Num
  FROM _Trade2
  WHERE Bitcoins > 0
  GROUP BY Week;

-- weekly average price from Price table (JPY). the price data for JPY is
-- sometimes missing for the date that we want.
CREATE TABLE _Weekly_Price_From_Price_Jpy (
  Week INT NOT NULL PRIMARY KEY, -- week after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp_Unix),
  Highest DOUBLE NOT NULL, -- highest price of the day
  Lowest  DOUBLE NOT NULL, -- lowest price of the day
  Average_Simple DOUBLE NOT NULL, -- simple average price of the day
  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Weekly_Price_From_Price_Jpy
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) Week,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400/7)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400/7)) AS Begin_Stamp,
    MAX(Price) Highest,
    MIN(Price) Lowest,
    AVG(Price) Average_Simple,
    COUNT(*) Num
  FROM Price
  WHERE Currency__='JPY'
  GROUP BY Week;

-- weekly average price from Price table (USD but converted to JPY). the price
-- data for USD the most abundant
CREATE TABLE _Weekly_Price_From_Price_Usd (
  Week INT NOT NULL PRIMARY KEY, -- week after beginning of sample period: 0, 1, ...
  Begin_Stamp_Unix DOUBLE NOT NULL, UNIQUE(Begin_Stamp_Unix), -- unix timestamp of the beginning of the day (00:00:00 UTC)
  Begin_Stamp DATETIME NOT NULL, UNIQUE(Begin_Stamp),
  Highest DOUBLE NOT NULL, -- highest price of the week
  Lowest  DOUBLE NOT NULL, -- lowest price of the week
  Average_Simple DOUBLE NOT NULL, -- simple average price of the week
  Num DOUBLE NOT NULL -- number of samples
);
INSERT INTO _Weekly_Price_From_Price_Usd
  SELECT
    FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) Week,
    ANY_VALUE(              1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400*7)  AS Begin_Stamp_Unix,
    ANY_VALUE(FROM_UNIXTIME(1301616000 + FLOOR((UNIX_TIMESTAMP(Stamp) - 1301616000)/86400/7) * 86400*7)) AS Begin_Stamp,
    MAX(Price) Highest,
    MIN(Price) Lowest,
    AVG(Price) Average_Simple,
    COUNT(*) Num
  FROM Price
  WHERE Currency__='USD'
  GROUP BY Week;
-- convert USD prices to JPY
UPDATE _Weekly_Price_From_Price_Usd t1 SET
  Highest       =Highest       *(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1),
  Lowest        =Lowest        *(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1),
  Average_Simple=Average_Simple*(SELECT Price FROM Fxrate t2 WHERE Currency1='USD' AND Currency2='JPY' ORDER BY ABS(DATEDIFF(t1.Begin_Stamp, t2.Stamp)) LIMIT 1)
  ;

-- daily average price change. see also: _Daily_Return table.
CREATE TABLE _Weekly_Price_Change (
  Week INT NOT NULL PRIMARY KEY,
  Percent_Change DOUBLE
);
INSERT INTO _Weekly_Price_Change
  SELECT
    Week,
    (Average-(SELECT Average FROM _Weekly_Price WHERE Week=p1.Week-1))/(SELECT Average FROM _Weekly_Price WHERE Week=p1.Week-1)*100 `Percent_Change`
  FROM _Weekly_Price p1;

-- calculate rank and percentile of trading activity
--CREATE TABLE _Trader_Rank_By_Num_Trades (
--  `Index` INT NOT NULL PRIMARY KEY,
--  Rank INT NOT NULL,
--  Percentile DOUBLE NOT NULL
--);
-- too slow, use script/gen-trader-rank
--SELECT
--  t1.`Index` `Index`,
--  COUNT(t2.Num_Trades)+1 AS Rank,
--  ((SELECT COUNT(*) FROM _Trade2_By_Index) - COUNT(t2.Num_Trades)) / (SELECT COUNT(*) FROM _Trade2_By_Index) * 100 AS Percentile
--FROM _Trade2_By_Index t1
--LEFT JOIN _Trade2_By_Index t2 ON t1.Num_Trades > t2.Num_Trades
--GROUP BY t1.`Index`;

-- daily survival data to be entered into statistical analysis software

SELECT
 s.Day Day,
 s.`Index` `Index`,
 s.Sold Sold,       -- event variable

 -- covariates

   -- time-varying
 s.TLI TLI, -- trading loss indicator, 0/1
 s.TGI TGI, -- trading gain indicator, 0/1
 COALESCE((s.Avg_Balance_Bitcoins_Market_Value-s.Avg_Balance_Bitcoins_Book_Value)/s.Avg_Balance_Bitcoins_Book_Value, 0) `Return`, -- current (unrealized) return
 p.`Percent_Change` Percent_Price_Change,
 IF(p.`Percent_Change` >  6.56, 1, 0) PII, -- price increase indicator, price today increase more than 6.565% compared to yesterday (top 10%)
 IF(p.`Percent_Change` < -4.34, 1, 0) PDI, -- price decrease indicator, price today decrease more than 6.565% compared to yesterday (bottom 10%)
 s.Avg_Purchase_Price Avg_Purchase_Price,
 s.Avg_Balance_Bitcoins Avg_Bal_Btc,
 s.Avg_Balance_Bitcoins_Book_Value Avg_Bal_Btc_BV,
 s.Avg_Balance_Bitcoins_Market_Value Avg_Bal_Btc_MV,

   -- non-time-varying
 IF(r.Percentile >= 90, 1, 0) Trader_Active, -- 1=within top 10% of trading activity, 0=no
 b.Average_Weighted_Bitcoins_Book_Value `Trader_Avg_Bal_Btc_BV`, -- in JPY
 t.Trade_Volume_Jpy/t.Num_Trades `Trader_Avg_Trade_Size`, -- in JPY
 FLOOR((1385855995 - UNIX_TIMESTAMP(t.First_Trade_Stamp))/86400) Trader_Account_Age -- proxied by first transaction date. in days before last day of sample period.

FROM _Daily_Survival s
LEFT JOIN _Trader_Balance b ON b.Period='all' AND s.`Index`=b.`Index`
LEFT JOIN _Trader_Rank_By_Num_Trades r ON s.`Index`=r.`Index`
LEFT JOIN _Daily_Price_Change p ON s.Day=p.Day
LEFT JOIN _Trade2_By_Index t ON s.`Index`=t.`Index`
;

-- timing: took 20+ mins on my laptop, 5.xGB output

-- weekly survival data to be entered into statistical analysis software

SELECT
 s.Week Week,
 s.`Index` `Index`,
 s.Sold Sold,       -- event variable

 -- covariates

   -- time-varying
 s.TLI TLI, -- trading loss indicator, 0/1
 s.TGI TGI, -- trading gain indicator, 0/1
 COALESCE((s.Avg_Balance_Bitcoins_Market_Value-s.Avg_Balance_Bitcoins_Book_Value)/s.Avg_Balance_Bitcoins_Book_Value, 0) `Return`, -- current (unrealized) return
 p.`Percent_Change` Percent_Price_Change,
 IF(p.`Percent_Change` >  27.845, 1, 0) PII, -- price increase indicator, price this week increase more than this % compared to last week (top 10%)
 IF(p.`Percent_Change` < -14.05 , 1, 0) PDI, -- price decrease indicator, price this week decrease more than this % compared to last week (bottom 10%)
 s.Avg_Purchase_Price Avg_Purchase_Price,
 s.Avg_Balance_Bitcoins Avg_Bal_Btc,
 s.Avg_Balance_Bitcoins_Book_Value Avg_Bal_Btc_BV,
 s.Avg_Balance_Bitcoins_Market_Value Avg_Bal_Btc_MV,

   -- non-time-varying
 IF(r.Percentile >= 90, 1, 0) Trader_Active, -- 1=within top 10% of trading activity, 0=no
 b.Average_Weighted_Bitcoins_Book_Value `Trader_Avg_Bal_Btc_BV`, -- in JPY
 t.Trade_Volume_Jpy/t.Num_Trades `Trader_Avg_Trade_Size`, -- in JPY
 FLOOR((1385855995 - UNIX_TIMESTAMP(t.First_Trade_Stamp))/86400) Trader_Account_Age -- proxied by first transaction date. in days before last day of sample period.

FROM _Weekly_Survival s
LEFT JOIN _Trader_Balance b ON b.Period='all' AND s.`Index`=b.`Index`
LEFT JOIN _Trader_Rank_By_Num_Trades r ON s.`Index`=r.`Index`
LEFT JOIN _Weekly_Price_Change p ON s.Week=p.Week
LEFT JOIN _Trade2_By_Index t ON s.`Index`=t.`Index`
;

-- timing: ~12min on my laptop, ~1.5min on my pc
-- timing: took 5 mins on my laptop, 1636 MB output
