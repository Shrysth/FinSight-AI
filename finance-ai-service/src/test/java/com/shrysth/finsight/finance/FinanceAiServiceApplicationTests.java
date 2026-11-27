package com.shrysth.finsight.finance;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = {
    "spring.ai.google.genai.api-key=test-key",
    "eureka.client.enabled=false",
    "spring.cloud.discovery.enabled=false"
})
class FinanceAiServiceApplicationTests {

    @Test
    void contextLoads() {
    }
}
