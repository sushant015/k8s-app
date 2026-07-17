package com.votepoll.auth;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public class HashGen {
    public static void main(String[] args) {
        System.out.println("DEBUG: Generating hash for password 'Sushant@12'");
        System.out.println(new BCryptPasswordEncoder().encode("Sushant@12"));
    }
}