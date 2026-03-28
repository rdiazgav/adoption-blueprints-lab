package com.retailflow.orders;

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "order_items")
public class OrderItem extends PanacheEntity {

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    public Order order;

    @Column(nullable = false)
    public String productId;

    @Column(nullable = false)
    public String productName;

    @Column(nullable = false)
    public Integer quantity;

    @Column(nullable = false, precision = 12, scale = 2)
    public BigDecimal unitPrice;
}
