package com.retailflow.catalog;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.math.BigDecimal;

public class CreateProductRequest {

    @NotBlank
    public String name;

    public String description;

    @NotBlank
    public String category;

    @NotNull
    @PositiveOrZero
    public BigDecimal price;

    @NotNull
    @PositiveOrZero
    public Integer stock;
}
