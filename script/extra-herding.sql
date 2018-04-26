-- before running this SQL script, you have to already run
-- gen-trader-daily-return-table script.

CREATE TABLE _Daily_Return_Dispersion_Period (
  Name VARCHAR(32) NOT NULL PRIMARY KEY,
  Begin_Stamp DATETIME NOT NULL,
  Begin_Day INT NOT NULL DEFAULT 0,
  End_Stamp DATETIME NOT NULL,
  End_Day INT NOT NULL DEFAULT 0
);
INSERT INTO _Daily_Return_Dispersion_Period (Name,Begin_Stamp,End_Stamp) VALUES ('all2', '2011-05-01 00:00:00', '2013-11-30 23:59:59');
INSERT INTO _Daily_Return_Dispersion_Period (Name,Begin_Stamp,End_Stamp) VALUES ('bear1', '2011-06-09 00:00:00', '2011-11-19 23:59:59');
INSERT INTO _Daily_Return_Dispersion_Period (Name,Begin_Stamp,End_Stamp) VALUES ('bull2', '2011-11-20 00:00:00', '2013-11-30 23:59:59');
UPDATE _Daily_Return_Dispersion_Period SET
  Begin_Day=FLOOR((UNIX_TIMESTAMP(Begin_Stamp) - 1301616000)/86400),
  End_Day  =FLOOR((UNIX_TIMESTAMP(End_Stamp  ) - 1301616000)/86400);

CREATE TABLE _Daily_Return_Dispersion_Participant (
  Period VARCHAR(32) NOT NULL,
  `Index` INT NOT NULL, INDEX(`Index`),
  UNIQUE(Period, `Index`)
);
INSERT INTO _Daily_Return_Dispersion_Participant
  SELECT p.Name, t.`Index` FROM _Trade2_By_Index t, _Daily_Return_Dispersion_Period p
  WHERE
    t.First_Buy_Stamp <= p.Begin_Stamp AND
    NOT EXISTS (
      SELECT `Index` FROM _Trade2 WHERE `Index`=t.`Index` AND (Stamp BETWEEN p.Begin_Stamp AND p.End_Stamp) AND Type='sell' AND Balance_Bitcoins=0
    ) AND
    NOT EXISTS (
      SELECT `Index` FROM _Trade2
      WHERE
        Stamp=(SELECT MAX(Stamp) FROM _Trade2 WHERE `Index`=t.`Index` AND Stamp BETWEEN t.First_Buy_Stamp AND p.Begin_Stamp) AND
        Type='sell' AND Balance_Bitcoins=0
    );
