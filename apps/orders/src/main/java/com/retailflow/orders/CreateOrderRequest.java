package com.retailflow.orders;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;
import java.util.List;

public class CreateOrderRequest {

    @NotBlank
    public String customerId;

    @NotEmpty
    @Valid
    public List<ItemRequest> items;

    public static class ItemRequest {

        @NotBlank
        public String productId;

        @NotBlank
        public String productName;

        @NotNull
        @Positive
        public Integer quantity;

        @NotNull
        @Positive
        public BigDecimal unitPrice;
    }
}
