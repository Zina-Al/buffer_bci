package nl.dcc.buffer_bci.cursor_control.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.GL20;

public class BlankScreenExit extends StimulusScreen {

    @Override
    public void draw() {
        Gdx.gl.glClearColor(0,0,0,0);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);
        Gdx.app.exit();
    }

    @Override
    public void update(float delta) {
    }
}
