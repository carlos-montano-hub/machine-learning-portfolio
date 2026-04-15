INSERT INTO
    warehouse.dim_product (
        product_id,
        product_english_category_name,
        product_category_name,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        product_volume_cm3,
        product_density_g_per_cm3
    )
SELECT DISTINCT
    products.product_id,
    product_category_name_translation.product_category_name_english,
    products.product_category_name,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    products.product_length_cm * products.product_height_cm * products.product_width_cm,
    CAST(products.product_weight_g AS DOUBLE) / (
        products.product_length_cm * products.product_height_cm * products.product_width_cm
    )
FROM
    olist.products AS products
    JOIN olist.product_category_name_translation AS product_category_name_translation ON products.product_category_name = product_category_name_translation.product_category_name
WHERE
    products.product_weight_g IS NOT NULL
    AND products.product_length_cm IS NOT NULL
    AND products.product_height_cm IS NOT NULL
    AND products.product_width_cm IS NOT NULL
    AND product_category_name_translation.product_category_name_english IS NOT NULL
    AND products.product_category_name IS NOT NULL
    AND products.product_weight_g > 0
    AND products.product_length_cm > 0
    AND products.product_height_cm > 0
    AND products.product_width_cm > 0;