INSERT INTO
    warehouse.dim_seller (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
SELECT DISTINCT
    sellers.seller_id,
    sellers.seller_zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state
FROM
    olist.sellers AS sellers
WHERE
    sellers.seller_zip_code_prefix IS NOT NULL
    AND sellers.seller_city IS NOT NULL
    AND sellers.seller_state IS NOT NULL;
