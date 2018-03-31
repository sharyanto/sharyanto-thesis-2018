-- reset result of calc-running-balances-and-gains

UPDATE _Trade2 SET
  Bitcoins_Change=0,
  Balance_Bitcoins=0,
  Balance_Bitcoins_Book_Value=0,
  Balance_Bitcoins_Market_Value=0,
  Avg_Purchase_Price=NULL,
  Paper_Gain=NULL,
  Balance_Jpy=0,
  Tx_Realized_Gain=NULL,
  Total_Realized_Gain=NULL
;

-- calculate average round-trip length (in days)

  -- all subperiodes
SELECT
  IF(Realized_Gain>0, 'GAIN', IF(Realized_Gain<0, 'LOSS', 'NEUTRAL')) status,
  COUNT(*) num,
  AVG(UNIX_TIMESTAMP(Weighted_Avg_End_Stamp)-UNIX_TIMESTAMP(Weighted_Avg_Begin_Stamp))/86400 avg_len
FROM _Round_Trip
GROUP BY status;

  -- subperiode bear1
SELECT
  IF(Realized_Gain>0, 'GAIN', IF(Realized_Gain<0, 'LOSS', 'NEUTRAL')) status,
  COUNT(*) num,
  AVG(UNIX_TIMESTAMP(Weighted_Avg_End_Stamp)-UNIX_TIMESTAMP(Weighted_Avg_Begin_Stamp))/86400 len
FROM _Round_Trip
WHERE First_Tx_Stamp >= '2011-06-09 00:00:00' AND Last_Tx_Stamp <= '2011-11-19 23:59:59'
GROUP BY status;

  -- by subperiodes (result is same as above)
SELECT
  p.Name,
  SUM(IF(r.First_Tx_Stamp >= p.Begin_Stamp AND r.Last_Tx_Stamp <= p.End_Stamp,1,0)) num,
  IF(Realized_Gain>0, 'GAIN', IF(Realized_Gain<0, 'LOSS', 'NEUTRAL')) status,
  AVG(IF(r.First_Tx_Stamp >= p.Begin_Stamp AND r.Last_Tx_Stamp <= p.End_Stamp,
         UNIX_TIMESTAMP(r.Weighted_Avg_End_Stamp)-UNIX_TIMESTAMP(r.Weighted_Avg_Begin_Stamp),
         NULL
        )
      )/86400 len
FROM _Round_Trip r, _Period p
GROUP BY p.Name, status
ORDER BY p.Name, status;
