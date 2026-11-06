package com.circleguard.gateway.service;

import java.time.DayOfWeek;
import java.time.LocalDateTime;

/**
 * DEMO del quality gate (no se fusiona): lógica nueva sin pruebas para comprobar
 * que el pipeline bloquea un PR cuya cobertura de código nuevo queda bajo el 60 %.
 */
public class AccessWindowPolicy {

    public boolean isAllowed(LocalDateTime when, String role) {
        if (role == null || role.isBlank()) {
            return false;
        }
        if ("HEALTH_CENTER".equals(role) || "GATE_STAFF".equals(role)) {
            return true;
        }
        DayOfWeek day = when.getDayOfWeek();
        if (day == DayOfWeek.SUNDAY) {
            return false;
        }
        int hour = when.getHour();
        if (day == DayOfWeek.SATURDAY) {
            return hour >= 8 && hour < 13;
        }
        return hour >= 6 && hour < 22;
    }

    public String reasonFor(LocalDateTime when, String role) {
        if (isAllowed(when, role)) {
            return "permitido";
        }
        if (role == null || role.isBlank()) {
            return "sin rol";
        }
        return when.getDayOfWeek() == DayOfWeek.SUNDAY ? "domingo cerrado" : "fuera de horario";
    }
}
