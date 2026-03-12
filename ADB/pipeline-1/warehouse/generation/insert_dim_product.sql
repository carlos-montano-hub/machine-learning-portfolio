INSERT INTO dim_product (
    product_id,
    product_english_category_name,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    products.product_id,
    product_category_name_translation.product_category_name_english,
    products.product_category_name,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm
FROM products
JOIN product_category_name_translation
  ON products.product_category_name =
     product_category_name_translation.product_category_name
WHERE
    products.product_weight_g IS NOT NULL AND
    products.product_length_cm IS NOT NULL AND
    products.product_height_cm IS NOT NULL AND
    products.product_width_cm IS NOT NULL AND
    product_category_name_translation.product_category_name_english IS NOT NULL AND
    products.product_category_name IS NOT NULL AND
    products.product_weight_g > 0 AND
    products.product_length_cm > 0 AND
    products.product_height_cm > 0 AND
    products.product_width_cm > 0
ON CONFLICT (product_id) DO UPDATE
SET
    product_english_category_name = EXCLUDED.product_english_category_name,
    product_category_name = EXCLUDED.product_category_name,
    product_weight_g = EXCLUDED.product_weight_g,
    product_length_cm = EXCLUDED.product_length_cm,
    product_height_cm = EXCLUDED.product_height_cm,
    product_width_cm = EXCLUDED.product_width_cm;
