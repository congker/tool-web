/**
 * @description:tool-web
 * @author: winsonxu
 * @createTime:2020/5/19
 */
package com.winson.toolweb.Controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("home")
@Slf4j
public class HomeController {
    /**
     * 方法描述
     */
    @RequestMapping(value = "/index")
    public String index() {
        return "index";
    }
}
