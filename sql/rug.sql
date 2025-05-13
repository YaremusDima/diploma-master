WITH
first_trade as (
    SELECT 
        IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', token_sold_address, token_bought_address) as token_address,
        IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', 'sell', 'buy') as action,
        project,
        pool_address,
        MIN(block_time) as first_trade_time
    FROM ton.dex_trades
    WHERE 1=1
        and project in ('dedust', 'ton.fun', 'gaspump')
        and volume_usd != 0
        and (
            token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000' or
            token_sold_address = '0:0000000000000000000000000000000000000000000000000000000000000000'
        )
    group by 1,2,3,4
    having 
            min(block_time) >= CAST('2024-01-01' as date)
        and min(block_time) <= CAST('2025-04-01' as date)
)
, trades as (
    SELECT 
        IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', token_sold_address, token_bought_address) as token_address,
        IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', 'sell', 'buy') as action,
        t.pool_address, 
        block_time,
        amount_bought_raw, 
        amount_sold_raw, 
        t.project,
        trader_address,
        IF(
            token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', 
            CAST(amount_bought_raw AS DOUBLE) / NULLIF(amount_sold_raw, 0), 
            CAST(amount_sold_raw AS DOUBLE) / NULLIF(amount_bought_raw, 0)
        ) as price,
        stb.first_trade_time as first_buy_time,
        sts.first_trade_time as first_sell_time,
        volume_usd, 
        volume_ton
    FROM 
        ton.dex_trades as t 
        LEFT JOIN first_trade as stb ON t.token_bought_address = stb.token_address and t.project = stb.project and t.pool_address = stb.pool_address and stb.action = IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', 'sell', 'buy')
        LEFT JOIN first_trade as sts ON t.token_sold_address = sts.token_address and t.project = sts.project and t.pool_address = sts.pool_address and sts.action = IF(token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000', 'sell', 'buy')
    WHERE 1=1
        and t.project in ('dedust', 'ton.fun', 'gaspump')
        and volume_usd != 0
        and (sts.first_trade_time is not null or stb.first_trade_time is not null)
        and (
            token_bought_address = '0:0000000000000000000000000000000000000000000000000000000000000000' or
            token_sold_address = '0:0000000000000000000000000000000000000000000000000000000000000000'
        )
        and block_time >= CAST('2024-01-01' as date)
        and block_time <= CAST('2025-04-02' as date)
)
, final_table as (
    SELECT
        token_address,
        action,
        pool_address, 
        block_time,
        amount_bought_raw, 
        amount_sold_raw, 
        project,
        trader_address,
        price,
        MIN(COALESCE(first_buy_time, CAST('2222-01-01' as date))) OVER (PARTITION BY token_address, pool_address, project) as first_buy_time,
        MIN(COALESCE(first_sell_time, CAST('2222-01-01' as date))) OVER (PARTITION BY token_address, pool_address, project) as first_sell_time,
        MIN(COALESCE(first_buy_time, first_sell_time)) OVER (PARTITION BY token_address, pool_address, project) as first_trade_time,
        volume_usd,
        volume_ton,
        LAG(block_time) OVER (PARTITION BY project, pool_address ORDER BY block_time) as prev_block_time
    FROM trades
)
-- , rug as (
--     SELECT
--         token_address,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '120' MINUTE) as alice_rugpull_60min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '180' MINUTE) as alice_rugpull_120min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '240' MINUTE) as alice_rugpull_180min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '300' MINUTE) as alice_rugpull_240min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '360' MINUTE) as alice_rugpull_300min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '420' MINUTE) as alice_rugpull_360min,
        -- COUNT(1) FILTER (WHERE block_time > first_trade_time + INTERVAL '60' MINUTE AND block_time > first_trade_time + INTERVAL '480' MINUTE) as alice_rugpull_420min
--     FROM final_table 
--     GROUP BY 1
--     -- LIMIT 1000
-- )
select
    count(1) as all_t,
    count_if(alice_rugpull_60min = 0) as rug_60,
    count_if(alice_rugpull_120min = 0) as rug_120,
    count_if(alice_rugpull_180min = 0) as rug_180,
    count_if(alice_rugpull_240min = 0) as rug_240,
    count_if(alice_rugpull_300min = 0) as rug_300,
    count_if(alice_rugpull_360min = 0) as rug_360,
    count_if(alice_rugpull_420min = 0) as rug_420
from rug